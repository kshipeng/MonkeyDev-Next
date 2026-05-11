MONKEYDEV_PATH="${MonkeyDevPath:-$HOME/.MonkeyDev}"

# temp path
TEMP_PATH="${BUILT_PRODUCTS_DIR}/MonkeyDevTemp"

# monkeyparser
MONKEYPARSER="${MONKEYDEV_PATH}/bin/monkeyparser"

# class-dump
CLASS_DUMP="${MONKEYDEV_PATH}/bin/class-dump"

# restore-symbol
RESTORE_SYMBOL="${MONKEYDEV_PATH}/bin/restore-symbol"

# create ipa script
CREATE_IPA="${MONKEYDEV_PATH}/bin/createIPA.command"

# build app path
BUILD_APP_PATH="${BUILT_PRODUCTS_DIR}/${TARGET_NAME}.app"

# default demo app
DEMOTARGET_APP_PATH="${MONKEYDEV_PATH}/Resource/TargetApp.app"

# link framework path
FRAMEWORKS_TO_INJECT_PATH="${MONKEYDEV_PATH}/Frameworks/"

# target app placed
TARGET_APP_PUT_PATH="${SRCROOT}/${TARGET_NAME}/TargetApp"

ORIGINAL_DYLIB_NAME="lib${TARGET_NAME}Dylib.dylib"

# Compatiable old version
MONKEYDEV_INSERT_DYLIB=${MONKEYDEV_INSERT_DYLIB:=YES}
MONKEYDEV_TARGET_APP=${MONKEYDEV_TARGET_APP:=Optional}
MONKEYDEV_ADD_SUBSTRATE=${MONKEYDEV_ADD_SUBSTRATE:=NO}
MONKEYDEV_DEFAULT_BUNDLEID=${MONKEYDEV_DEFAULT_BUNDLEID:=YES}
MONKEYDEV_CREATE_SIGN_IPA=${MONKEYDEV_CREATE_SIGN_IPA:=YES}

if [[ -n "${MONKEYDEV_DYLIB_NAME}" ]]; then
    # 自定义名称：100%原样使用（支持无后缀、隐藏文件、特殊命名）
    FULL_DYLIB_NAME="${MONKEYDEV_DYLIB_NAME}"
else
    # 默认逻辑：完全沿用原有拼接规则
    FULL_DYLIB_NAME="${ORIGINAL_DYLIB_NAME}"
fi

function isRelease() {
	if [[ "${CONFIGURATION}" = "Release" ]]; then
		true
	else
		false
	fi
}

function panic() { # args: exitCode, message...
	local exitCode=$1
	set +e
	
	shift
	[[ "$@" == "" ]] || \
		echo "$@" >&2

	exit ${exitCode}
}

function checkApp(){
    local TARGET_APP_PATH="$1"

    # remove Plugin an Watch
    rm -rf "${TARGET_APP_PATH}/PlugIns" || true
    rm -rf "${TARGET_APP_PATH}/Watch" || true

    /usr/libexec/PlistBuddy -c 'Delete UISupportedDevices' "${TARGET_APP_PATH}/Info.plist" 2>/dev/null

    APP_BINARY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "${TARGET_APP_PATH}/Info.plist" 2>/dev/null)
    APP_BINARY_PATH="${TARGET_APP_PATH}/${APP_BINARY_NAME}"

    # 1. 独立接管 Class Dump
    if [[ "${MONKEYDEV_CLASS_DUMP}" == "YES" ]]; then
        DUMP_DIR="${SRCROOT}/DumpHeaders"
        rm -rf "${DUMP_DIR}"
        mkdir -p "${DUMP_DIR}"
        if [[ -f "${CLASS_DUMP}" ]]; then
            "${CLASS_DUMP}" -H "${APP_BINARY_PATH}" -o "${DUMP_DIR}" 2>/dev/null
            echo "✅ Class-dump 提取成功: ${DUMP_DIR}"
        else
            echo "⚠️ 警告: 未找到 ${CLASS_DUMP}，跳过头文件导出。"
        fi
    fi

    # 2. 独立接管 Restore Symbol (根据你的环境进行动态容错)
    if [[ "${MONKEYDEV_RESTORE_SYMBOL}" == "YES" ]]; then
        if [[ -f "${RESTORE_SYMBOL}" ]]; then
            "${RESTORE_SYMBOL}" "${APP_BINARY_PATH}" -o "${APP_BINARY_PATH}_with_symbol"
            mv "${APP_BINARY_PATH}_with_symbol" "${APP_BINARY_PATH}"
            echo "✅ Restoresymbol 符号还原成功。"
        else
            echo "⚠️ 警告: 未找到 ${RESTORE_SYMBOL}，你的二进制文件可能仍处于无符号状态。"
        fi
    fi
}

function pack(){
	TARGET_INFO_PLIST=${SRCROOT}/${TARGET_NAME}/Info.plist
	# environment
	CURRENT_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "${TARGET_INFO_PLIST}" 2>/dev/null)

	# create tmp dir
	rm -rf "${TEMP_PATH}" || true
	mkdir -p "${TEMP_PATH}" || true

	# latestbuild
	ln -fhs "${BUILT_PRODUCTS_DIR}" "${PROJECT_DIR}"/LatestBuild
	cp -rf "${CREATE_IPA}" "${PROJECT_DIR}"/LatestBuild/

	# deal ipa or app
	TARGET_APP_PATH=$(find "${SRCROOT}/${TARGET_NAME}" -type d | grep "\.app$" | head -n 1)
	TARGET_IPA_PATH=$(find "${SRCROOT}/${TARGET_NAME}" -type f | grep "\.ipa$" | head -n 1)

	if [[ ${TARGET_APP_PATH} ]]; then
		cp -rf "${TARGET_APP_PATH}" "${TARGET_APP_PUT_PATH}"
	fi

	if [[ ! ${TARGET_APP_PATH} ]] && [[ ! ${TARGET_IPA_PATH} ]] && [[ ${MONKEYDEV_TARGET_APP} != "Optional" ]]; then
		echo "pulling decrypted ipa from jailbreak device......."
		PYTHONIOENCODING=utf-8 ${MONKEYDEV_PATH}/bin/dump.py ${MONKEYDEV_TARGET_APP} -o "${TARGET_APP_PUT_PATH}/TargetApp.ipa" || panic 1 "dump.py error"
		TARGET_IPA_PATH=$(find "${TARGET_APP_PUT_PATH}" -type f | grep "\.ipa$" | head -n 1)
	fi

	if [[ ! ${TARGET_APP_PATH} ]] && [[ ${TARGET_IPA_PATH} ]]; then
        ditto -x -k "$TARGET_IPA_PATH" "$TEMP_PATH"
		cp -rf "${TEMP_PATH}/Payload/"*.app "${TARGET_APP_PUT_PATH}"
	fi
	
	if [ -f "${BUILD_APP_PATH}/embedded.mobileprovision" ]; then
		mv "${BUILD_APP_PATH}/embedded.mobileprovision" "${BUILD_APP_PATH}"/..
	fi

	TARGET_APP_PATH=$(find "${TARGET_APP_PUT_PATH}" -type d | grep "\.app$" | head -n 1)

	if [[ -f "${TARGET_APP_PUT_PATH}"/.current_put_app ]]; then
		if [[ $(cat ${TARGET_APP_PUT_PATH}/.current_put_app) !=  "${TARGET_APP_PATH}" ]]; then
			rm -rf "${BUILD_APP_PATH}" || true
		 	mkdir -p "${BUILD_APP_PATH}" || true
		 	rm -rf "${TARGET_APP_PUT_PATH}"/.current_put_app
			echo "${TARGET_APP_PATH}" >> "${TARGET_APP_PUT_PATH}"/.current_put_app
		fi
	fi

	COPY_APP_PATH=${TARGET_APP_PATH}

	if [[ "${TARGET_APP_PATH}" = "" ]]; then
		COPY_APP_PATH=${DEMOTARGET_APP_PATH}
		cp -rf "${COPY_APP_PATH}/" "${BUILD_APP_PATH}/"
		checkApp "${BUILD_APP_PATH}"
	else
		checkApp "${COPY_APP_PATH}"
		cp -rf "${COPY_APP_PATH}/" "${BUILD_APP_PATH}/"
	fi

    if [[ -d "${COPY_APP_PATH}" && "${COPY_APP_PATH}" != "${DEMOTARGET_APP_PATH}" ]]; then
        echo "🔄 尝试提取原应用图标以替换 Xcode Scheme 图标..."
        ICON_DEST="${SRCROOT}/${TARGET_NAME}/icon.png"
        EXTRACTED_ICON=""

        if [[ -f "${COPY_APP_PATH}/iTunesArtwork" ]]; then
            EXTRACTED_ICON="${COPY_APP_PATH}/iTunesArtwork"
        else
            ICON_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconFiles:0" "${COPY_APP_PATH}/Info.plist" 2>/dev/null)
            if [[ -n "${ICON_NAME}" ]]; then
                EXTRACTED_ICON=$(find "${COPY_APP_PATH}" -maxdepth 1 -name "${ICON_NAME}*.png" | head -n 1)
            fi
            
            if [[ -z "${EXTRACTED_ICON}" || ! -f "${EXTRACTED_ICON}" ]]; then
                EXTRACTED_ICON=$(find "${COPY_APP_PATH}" -maxdepth 1 -iname "*AppIcon*.png" -o -iname "*Icon*.png" | grep -v "Back" | sort -r | head -n 1)
            fi
        fi

        # 执行替换动作
        if [[ -n "${EXTRACTED_ICON}" && -f "${EXTRACTED_ICON}" ]]; then
            cp -f "${EXTRACTED_ICON}" "${ICON_DEST}"
            echo "✅ 成功提取并替换工程图标: $(basename "${EXTRACTED_ICON}") -> icon.png"
        else
            echo "⚠️ 图标可能已被深度编译至 Assets.car 中，纯 Shell 无法直接解包。请使用 iOS Image Extractor 手动提取并替换 ${ICON_DEST}。"
        fi
    fi

	if [ -f "${BUILD_APP_PATH}/../embedded.mobileprovision" ]; then
		mv "${BUILD_APP_PATH}/../embedded.mobileprovision" "${BUILD_APP_PATH}"
	fi

	# get target info
	ORIGIN_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier"  "${COPY_APP_PATH}/Info.plist" 2>/dev/null)
	TARGET_EXECUTABLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable"  "${COPY_APP_PATH}/Info.plist" 2>/dev/null)

	if [[ ${CURRENT_EXECUTABLE} != ${TARGET_EXECUTABLE} ]]; then
		cp -rf "${COPY_APP_PATH}/Info.plist" "${TARGET_INFO_PLIST}"
	fi

	TARGET_DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName" "${TARGET_INFO_PLIST}" 2>/dev/null)

	# copy default framewrok
	TARGET_APP_FRAMEWORKS_PATH="${BUILD_APP_PATH}/Frameworks/"

	if [ ! -d "${TARGET_APP_FRAMEWORKS_PATH}" ]; then
		mkdir -p "${TARGET_APP_FRAMEWORKS_PATH}"
	fi

    ORIGINAL_FRAMEWORKS_SNAPSHOT="${TEMP_PATH}/original_frameworks_snapshot.txt"
    ls -1 "${COPY_APP_PATH}/Frameworks/" > "${ORIGINAL_FRAMEWORKS_SNAPSHOT}" 2>/dev/null || true

	if [[ ${MONKEYDEV_INSERT_DYLIB} == "YES" ]];then
        rm -f "${TARGET_APP_FRAMEWORKS_PATH}/${ORIGINAL_DYLIB_NAME}"
        rm -f "${TARGET_APP_FRAMEWORKS_PATH}/${FULL_DYLIB_NAME}"
        cp -rf "${FRAMEWORKS_TO_INJECT_PATH}" "${TARGET_APP_FRAMEWORKS_PATH}"
        rm -rf "${TARGET_APP_FRAMEWORKS_PATH}"/.keep
		cp -rf "${BUILT_PRODUCTS_DIR}/${ORIGINAL_DYLIB_NAME}" "${TARGET_APP_FRAMEWORKS_PATH}/${FULL_DYLIB_NAME}"
		if [[ ${MONKEYDEV_ADD_SUBSTRATE} != "YES" ]];then
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}/libsubstrate.dylib"
		fi
		if isRelease; then
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}"/RevealServer.framework
			rm -rf "${TARGET_APP_FRAMEWORKS_PATH}"/libcycript*
		fi
	fi

	if [[ -d "$SRCROOT/${TARGET_NAME}/Resources" ]]; then
	 for file in "$SRCROOT/${TARGET_NAME}/Resources"/*; do
	 	extension="${file#*.}"
	  	filename="${file##*/}"
	  	if [[ "$extension" == "storyboard" ]]; then
	  		ibtool --compile "${BUILD_APP_PATH}/$filename"c "$file"
	  	else
	  		cp -rf "$file" "${BUILD_APP_PATH}/"
	  	fi
	 done
	fi

	# Inject the Dynamic Lib
    APP_BINARY=`plutil -convert xml1 -o - ${BUILD_APP_PATH}/Info.plist | grep -A1 Exec | tail -n1 | cut -f2 -d\> | cut -f1 -d\<`

    if [[ ${MONKEYDEV_INSERT_DYLIB} == "YES" ]];then
        "$MONKEYPARSER" install -c load -p "@executable_path/Frameworks/${FULL_DYLIB_NAME}" -t "${BUILD_APP_PATH}/${APP_BINARY}"
        "$MONKEYPARSER" unrestrict -t "${BUILD_APP_PATH}/${APP_BINARY}"

        chmod +x "${BUILD_APP_PATH}/${APP_BINARY}"
    fi

	# Update Info.plist for Target App
	if [[ "${TARGET_DISPLAY_NAME}" != "" ]]; then
		for file in `ls "${BUILD_APP_PATH}"`;
		do
			extension="${file#*.}"
		    if [[ -d "${BUILD_APP_PATH}/$file" ]]; then
				if [[ "${extension}" == "lproj" ]]; then
					if [[ -f "${BUILD_APP_PATH}/${file}/InfoPlist.strings" ]];then
						/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${TARGET_DISPLAY_NAME}" "${BUILD_APP_PATH}/${file}/InfoPlist.strings" 2>/dev/null || \
                        /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string ${TARGET_DISPLAY_NAME}" "${BUILD_APP_PATH}/${file}/InfoPlist.strings" 2>/dev/null
					fi
		    	fi
			fi
		done
	fi

	if [[ ${MONKEYDEV_DEFAULT_BUNDLEID} = NO ]];then 
		/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${PRODUCT_BUNDLE_IDENTIFIER}" "${TARGET_INFO_PLIST}"
	else
		/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${ORIGIN_BUNDLE_ID}" "${TARGET_INFO_PLIST}"
	fi

    /usr/libexec/PlistBuddy -c "Delete :UIDeviceFamily" "${TARGET_INFO_PLIST}" 2>/dev/null

	cp -rf "${TARGET_INFO_PLIST}" "${BUILD_APP_PATH}/Info.plist"

	#cocoapods
	if [[ -f "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh" ]]; then
		source "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	fi

	if [[ -f "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh" ]]; then
		source "${SRCROOT}/Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	fi

	if [[ -f "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh" ]]; then
		source "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-frameworks.sh"
	fi

	if [[ -f "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh" ]]; then
		source "${SRCROOT}/../Pods/Target Support Files/Pods-""${TARGET_NAME}""Dylib/Pods-""${TARGET_NAME}""Dylib-resources.sh"
	fi
 
    if [[ -d "${TARGET_APP_FRAMEWORKS_PATH}" ]]; then
        find "${TARGET_APP_FRAMEWORKS_PATH}" -type f | while read -r lib_file; do
            
            local relative_path="${lib_file#${TARGET_APP_FRAMEWORKS_PATH}}"
            relative_path="${relative_path#/}"
            local top_level_item="${relative_path%%/*}"

            if grep -qx "${top_level_item}" "${ORIGINAL_FRAMEWORKS_SNAPSHOT}" 2>/dev/null; then
                continue
            fi

            if file "$lib_file" | grep -q "Mach-O"; then
                local lib_name=$(basename "$lib_file")
                
                if [[ "$lib_name" != "${FULL_DYLIB_NAME}" ]] && [[ "$lib_name" != "libsubstrate.dylib" ]]; then
                    local standard_install_path="@executable_path/Frameworks/$lib_name"
                    install_name_tool -id "$standard_install_path" "$lib_file" 2>/dev/null
                fi
                
                local deps=$(otool -L "$lib_file" 2>/dev/null | awk 'NR>1 {print $1}')
                for dep_path in $deps; do
                    local dep_name=$(basename "$dep_path")
                    
                    if [[ -f "${TARGET_APP_FRAMEWORKS_PATH}/$dep_name" ]]; then
                        local new_dep_path="@executable_path/Frameworks/$dep_name"
                        if [[ "$dep_path" != "$new_dep_path" ]]; then
                            install_name_tool -change "$dep_path" "$new_dep_path" "$lib_file" 2>/dev/null
                        fi
                        continue
                    fi
                    
                    if [[ "$dep_path" == /System/Library/* ]] || [[ "$dep_path" == /usr/lib/* ]] || [[ "$dep_path" == @rpath/* ]] || [[ "$dep_path" == @executable_path/* ]]; then
                        continue
                    fi
                    
                    local new_dep_path="@executable_path/Frameworks/$dep_name"
                    install_name_tool -change "$dep_path" "$new_dep_path" "$lib_file" 2>/dev/null
                done
            fi
        done
    fi
}

function build_custom_ipa() {
    TARGET_INFO_PLIST="${BUILD_APP_PATH}/Info.plist"
    DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleDisplayName" "${TARGET_INFO_PLIST}" 2>/dev/null)
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${TARGET_INFO_PLIST}" 2>/dev/null)
    EXECUTABLE_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleExecutable" "${TARGET_INFO_PLIST}" 2>/dev/null)
    
    if [[ -z "${DISPLAY_NAME}" ]]; then
        DISPLAY_NAME=$(/usr/libexec/PlistBuddy -c "Print CFBundleName" "${TARGET_INFO_PLIST}" 2>/dev/null)
    fi
    
    DISPLAY_NAME=${DISPLAY_NAME:-"TargetApp"}
    VERSION=${VERSION:-"1.0.0"}
    EXECUTABLE_NAME=${EXECUTABLE_NAME:-${TARGET_NAME}}
    
    IPA_NAME="${DISPLAY_NAME}_${VERSION}.ipa"
    IPA_PATH="${BUILT_PRODUCTS_DIR}/${IPA_NAME}"

    rm -rf "${IPA_PATH}" "${BUILT_PRODUCTS_DIR}/Payload"
    
    mkdir -p "${BUILT_PRODUCTS_DIR}/Payload"
    PAYLOAD_APP_PATH="${BUILT_PRODUCTS_DIR}/Payload/${EXECUTABLE_NAME}.app"
    cp -rf "${BUILD_APP_PATH}" "${PAYLOAD_APP_PATH}"
    
    if [[ ${MONKEYDEV_CREATE_SIGN_IPA} == "NO" ]];then
        rm -rf "${PAYLOAD_APP_PATH}/embedded.mobileprovision"
        rm -rf "${PAYLOAD_APP_PATH}/_CodeSignature"
        rm -rf "${PAYLOAD_APP_PATH}/CodeResources"
        
        FRAMEWORK_PATHS=$(find "${PAYLOAD_APP_PATH}/Frameworks" -type d -name "*.framework")
        for FRAMEWORK in ${FRAMEWORK_PATHS}; do
            rm -rf "${FRAMEWORK}/_CodeSignature"
            rm -rf "${FRAMEWORK}/CodeResources"
        done
        
        APPEX_PATHS=$(find "${PAYLOAD_APP_PATH}/PlugIns" -type d -name "*.appex" 2>/dev/null)
        for APPEX in ${APPEX_PATHS}; do
            rm -rf "${APPEX}/embedded.mobileprovision"
            rm -rf "${APPEX}/_CodeSignature"
            rm -rf "${APPEX}/CodeResources"
        done
    fi
    
    cd "${BUILT_PRODUCTS_DIR}"
    zip -qr "${IPA_NAME}" Payload/ -x "*.DS_Store" -x "*__MACOSX*"
    
    rm -rf "${BUILT_PRODUCTS_DIR}/Payload"
    
    if [[ -f "${IPA_PATH}" ]]; then
        cp -rf "${IPA_PATH}" "${PROJECT_DIR}/LatestBuild/"
        echo "✅ IPA已同步到：${PROJECT_DIR}/LatestBuild/${IPA_NAME}"
        echo "📂 IPA内部结构已修正为: Payload/${EXECUTABLE_NAME}.app"
    else
        echo "❌ IPA打包失败！"
        exit 1
    fi
}

function perform_codesign() {
    echo "🔒 开始执行重签名与封包流程..."
    
    if [[ ${MONKEYDEV_INSERT_DYLIB} == "NO" ]];then
        rm -rf "${BUILD_APP_PATH}/Frameworks/${FULL_DYLIB_NAME}"
    fi
    
    "${MONKEYPARSER}" codesign -i "${EXPANDED_CODE_SIGN_IDENTITY}" -t "${BUILD_APP_PATH}"

    ENT_FILE="${TEMP_PATH}/extracted_entitlements.plist"
    /usr/bin/codesign -d --entitlements :- "${BUILD_APP_PATH}" > "${ENT_FILE}" 2>/dev/null || true

    find "${BUILD_APP_PATH}" \( -name "*.framework" -o -name "*.appex" -o -name "*.dylib" \) | while read -r item; do
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --generate-entitlement-der "$item"
    done

    if [ -s "${ENT_FILE}" ]; then
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --entitlements "${ENT_FILE}" --generate-entitlement-der "${BUILD_APP_PATH}"
    else
        /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --generate-entitlement-der "${BUILD_APP_PATH}"
    fi
    
    build_custom_ipa
}

if [[ "$1" == "codesign" ]]; then
    perform_codesign
elif [[ "$1" == "pack" ]]; then
    pack
elif [[ "$1" == "all" ]]; then
    pack
    perform_codesign
else
    pack
fi
