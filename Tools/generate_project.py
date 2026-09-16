#!/usr/bin/env python3
"""
Мини-генератор MAPA.xcodeproj.

Зачем: на проекте будет 14 этапов и десятки новых файлов. Вместо ручной
правки project.pbxproj (и конфликтов в git) мы просто сканируем папку MAPA/
и переписываем проект целиком. Добавил файл -> запустил скрипт -> готово.

Использование:
    python3 Tools/generate_project.py
"""

import hashlib
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = "MAPA"
BUNDLE_ID = "com.mapa.app"
DEPLOYMENT_TARGET = "16.0"   # поднимем до 17.0, когда встанет Xcode 15+
MARKETING_VERSION = "0.1.0"

SRC_ROOT = os.path.join(ROOT, APP)
PROJ_DIR = os.path.join(ROOT, APP + ".xcodeproj")

SOURCE_EXT = {".swift"}
RESOURCE_EXT = {".xcassets", ".json", ".geojson", ".strings", ".xcstrings", ".ttf", ".otf", ".png"}
BUNDLE_DIRS = {".xcassets"}          # папки, которые Xcode видит как единый файл
SKIP = {".DS_Store"}


def uid(*parts: str) -> str:
    return hashlib.md5("::".join(parts).encode("utf-8")).hexdigest().upper()[:24]


class Node:
    def __init__(self, name, path, is_dir):
        self.name = name
        self.path = path            # относительный путь от корня репозитория
        self.is_dir = is_dir
        self.children = []


def scan(abs_path, rel_path) -> Node:
    node = Node(os.path.basename(rel_path), rel_path, True)
    for entry in sorted(os.listdir(abs_path)):
        if entry in SKIP or entry.startswith("."):
            continue
        child_abs = os.path.join(abs_path, entry)
        child_rel = os.path.join(rel_path, entry)
        ext = os.path.splitext(entry)[1]
        if os.path.isdir(child_abs) and ext not in BUNDLE_DIRS:
            sub = scan(child_abs, child_rel)
            if sub.children:
                node.children.append(sub)
        else:
            if ext in SOURCE_EXT or ext in RESOURCE_EXT:
                node.children.append(Node(entry, child_rel, False))
    return node


def file_type(name: str) -> str:
    ext = os.path.splitext(name)[1]
    return {
        ".swift": "sourcecode.swift",
        ".xcassets": "folder.assetcatalog",
        ".json": "text.json",
        ".geojson": "text.json",
        ".strings": "text.plist.strings",
        ".xcstrings": "text.json.xcstrings",
        ".png": "image.png",
        ".ttf": "file",
        ".otf": "file",
    }.get(ext, "text")


def collect(node, sources, resources):
    for child in node.children:
        if child.is_dir:
            collect(child, sources, resources)
        elif os.path.splitext(child.name)[1] in SOURCE_EXT:
            sources.append(child)
        else:
            resources.append(child)


def emit_groups(node, lines, is_root):
    for child in node.children:
        if child.is_dir:
            emit_groups(child, lines, False)
    children_refs = "\n".join(
        "\t\t\t\t{} /* {} */,".format(uid("group", c.path) if c.is_dir else uid("file", c.path), c.name)
        for c in node.children
    )
    lines.append(
        "\t\t{gid} /* {name} */ = {{\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n{kids}\n\t\t\t);\n"
        "\t\t\tpath = {name};\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}};".format(gid=uid("group", node.path), name=node.name, kids=children_refs)
    )


def generate():
    tree = scan(SRC_ROOT, APP)
    sources, resources = [], []
    collect(tree, sources, resources)

    target_id = uid("target", APP)
    project_id = uid("project", APP)
    product_id = uid("product", APP)
    main_group_id = uid("maingroup", APP)
    products_group_id = uid("products", APP)

    group_lines = []
    emit_groups(tree, group_lines, True)
    group_lines.append(
        "\t\t{gid} /* Products */ = {{\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n\t\t\t\t{pid} /* {app}.app */,\n\t\t\t);\n"
        "\t\t\tname = Products;\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}};".format(gid=products_group_id, pid=product_id, app=APP)
    )
    group_lines.append(
        "\t\t{gid} = {{\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n\t\t\t\t{src} /* {app} */,\n\t\t\t\t{prod} /* Products */,\n\t\t\t);\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}};".format(gid=main_group_id, src=uid("group", APP), app=APP, prod=products_group_id)
    )

    file_refs = []
    for f in sources + resources:
        file_refs.append(
            "\t\t{fid} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = {name}; sourceTree = \"<group>\"; }};".format(
                fid=uid("file", f.path), name=f.name, ftype=file_type(f.name)
            )
        )
    file_refs.append(
        "\t\t{pid} /* {app}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {app}.app; sourceTree = BUILT_PRODUCTS_DIR; }};".format(
            pid=product_id, app=APP
        )
    )

    build_files = []
    for f in sources + resources:
        build_files.append(
            "\t\t{bid} /* {name} in Build */ = {{isa = PBXBuildFile; fileRef = {fid} /* {name} */; }};".format(
                bid=uid("build", f.path), name=f.name, fid=uid("file", f.path)
            )
        )

    src_phase = "\n".join("\t\t\t\t{} /* {} */,".format(uid("build", f.path), f.name) for f in sources)
    res_phase = "\n".join("\t\t\t\t{} /* {} */,".format(uid("build", f.path), f.name) for f in resources)

    base_settings = """				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu11;
				GCC_NO_COMMON_BLOCKS = YES;
				IPHONEOS_DEPLOYMENT_TARGET = {dt};
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
				SWIFT_VERSION = 5.0;""".format(dt=DEPLOYMENT_TARGET)

    debug_settings = base_settings + """
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";"""

    release_settings = base_settings + """
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				MTL_ENABLE_DEBUG_INFO = NO;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;"""

    target_settings = """				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = MAPA;
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "\u041f\u043e\u043a\u0430\u0436\u0435\u043c, \u0432 \u043a\u0430\u043a\u043e\u0439 \u0442\u044b \u0441\u0442\u0440\u0430\u043d\u0435, \u0438 \u0441\u0440\u0430\u0437\u0443 \u043f\u0440\u0438\u0431\u043b\u0438\u0437\u0438\u043c \u043a \u043d\u0435\u0439 \u043a\u0430\u0440\u0442\u0443.";
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UIStatusBarStyle = UIStatusBarStyleLightContent;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UIUserInterfaceStyle = Dark;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = {mv};
				PRODUCT_BUNDLE_IDENTIFIER = {bid};
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 1;""".format(mv=MARKETING_VERSION, bid=BUNDLE_ID)

    pbx = """// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_files}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{groups}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target_id} /* {app} */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {target_cfg_list} /* Build configuration list for PBXNativeTarget "{app}" */;
			buildPhases = (
				{sources_id} /* Sources */,
				{frameworks_id} /* Frameworks */,
				{resources_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = {app};
			productName = {app};
			productReference = {product_id} /* {app}.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1420;
				LastUpgradeCheck = 1420;
				TargetAttributes = {{
					{target_id} = {{
						CreatedOnToolsVersion = 14.2;
					}};
				}};
			}};
			buildConfigurationList = {project_cfg_list} /* Build configuration list for PBXProject "{app}" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				ru,
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target_id} /* {app} */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{res_phase}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{src_phase}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{proj_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{debug_settings}
			}};
			name = Debug;
		}};
		{proj_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{release_settings}
			}};
			name = Release;
		}};
		{tgt_debug} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{target_settings}
			}};
			name = Debug;
		}};
		{tgt_release} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
{target_settings}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{project_cfg_list} /* Build configuration list for PBXProject "{app}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug} /* Debug */,
				{proj_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{target_cfg_list} /* Build configuration list for PBXNativeTarget "{app}" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{tgt_debug} /* Debug */,
				{tgt_release} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project_id} /* Project object */;
}}
""".format(
        app=APP,
        build_files="\n".join(build_files),
        file_refs="\n".join(file_refs),
        groups="\n".join(group_lines),
        src_phase=src_phase,
        res_phase=res_phase,
        debug_settings=debug_settings,
        release_settings=release_settings,
        target_settings=target_settings,
        target_id=target_id,
        project_id=project_id,
        product_id=product_id,
        main_group_id=main_group_id,
        products_group_id=products_group_id,
        frameworks_id=uid("phase", "frameworks"),
        sources_id=uid("phase", "sources"),
        resources_id=uid("phase", "resources"),
        project_cfg_list=uid("cfglist", "project"),
        target_cfg_list=uid("cfglist", "target"),
        proj_debug=uid("cfg", "project.debug"),
        proj_release=uid("cfg", "project.release"),
        tgt_debug=uid("cfg", "target.debug"),
        tgt_release=uid("cfg", "target.release"),
    )

    if os.path.isdir(PROJ_DIR):
        shutil.rmtree(PROJ_DIR)
    os.makedirs(os.path.join(PROJ_DIR, "project.xcworkspace", "xcshareddata"))
    with open(os.path.join(PROJ_DIR, "project.pbxproj"), "w") as fh:
        fh.write(pbx)
    with open(os.path.join(PROJ_DIR, "project.xcworkspace", "contents.xcworkspacedata"), "w") as fh:
        fh.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<Workspace version = "1.0">\n'
            '   <FileRef location = "self:">\n'
            '   </FileRef>\n'
            '</Workspace>\n'
        )
    with open(os.path.join(PROJ_DIR, "project.xcworkspace", "xcshareddata", "IDEWorkspaceChecks.plist"), "w") as fh:
        fh.write(
            '<?xml version="1.0" encoding="UTF-8"?>\n'
            '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n'
            '<plist version="1.0">\n<dict>\n'
            '\t<key>IDEDidComputeMac32BitWarning</key>\n\t<true/>\n'
            '</dict>\n</plist>\n'
        )

    print("MAPA.xcodeproj пересобран: {} исходников, {} ресурсов".format(len(sources), len(resources)))


if __name__ == "__main__":
    generate()
