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
TESTS = APP + "Tests"
TESTS_ROOT = os.path.join(ROOT, TESTS)
PROJ_DIR = os.path.join(ROOT, APP + ".xcodeproj")

SOURCE_EXT = {".swift"}
RESOURCE_EXT = {".xcassets", ".json", ".geojson", ".strings", ".stringsdict",
                ".xcstrings", ".ttf", ".otf", ".png", ".xcprivacy"}
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
        ".stringsdict": "text.plist.stringsdict",
        ".xcstrings": "text.json.xcstrings",
        ".png": "image.png",
        ".xcprivacy": "text.xml",
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


def insert_before(text: str, marker: str, block: str) -> str:
    """Вставляет блок перед закрывающим маркером секции pbxproj."""
    index = text.index(marker)
    return text[:index] + block + "\n" + text[index:]


def add_tests(pbx, names, app_target, project_id, main_group, products_group):
    """Прицепляет цель юнит-тестов к уже собранному проекту.

    Вставкой в готовый текст, а не ещё десятью подстановками в шаблон:
    секции pbxproj размечены комментариями «Begin/End», и дописать блок
    перед закрывающим маркером надёжнее, чем плодить плейсхолдеры.
    """
    t_target = uid("target", TESTS)
    t_product = uid("product", TESTS)
    t_group = uid("group", TESTS)
    t_sources = uid("phase", "tests.sources")
    t_frameworks = uid("phase", "tests.frameworks")
    t_cfglist = uid("cfglist", "tests")
    t_debug = uid("cfg", "tests.debug")
    t_release = uid("cfg", "tests.release")
    t_dep = uid("dep", TESTS)
    t_proxy = uid("proxy", TESTS)

    refs = []
    builds = []
    for name in names:
        file_id = uid("file", TESTS + "/" + name)
        build_id = uid("build", TESTS + "/" + name)
        refs.append('\t\t{} /* {} */ = {{isa = PBXFileReference; lastKnownFileType = '
                    'sourcecode.swift; path = {}; sourceTree = "<group>"; }};'
                    .format(file_id, name, name))
        builds.append('\t\t{} /* {} in Sources */ = {{isa = PBXBuildFile; fileRef = {} /* {} */; }};'
                      .format(build_id, name, file_id, name))

    refs.append('\t\t{} /* {}.xctest */ = {{isa = PBXFileReference; explicitFileType = '
                'wrapper.cfbundle; includeInIndex = 0; path = {}.xctest; '
                'sourceTree = BUILT_PRODUCTS_DIR; }};'.format(t_product, TESTS, TESTS))

    pbx = insert_before(pbx, "/* End PBXFileReference section */", "\n".join(refs))
    pbx = insert_before(pbx, "/* End PBXBuildFile section */", "\n".join(builds))

    kids = "\n".join("\t\t\t\t{} /* {} */,".format(uid("file", TESTS + "/" + n), n)
                     for n in names)
    pbx = insert_before(pbx, "/* End PBXGroup section */",
        "\t\t{gid} /* {t} */ = {{\n"
        "\t\t\tisa = PBXGroup;\n"
        "\t\t\tchildren = (\n{kids}\n\t\t\t);\n"
        "\t\t\tpath = {t};\n"
        "\t\t\tsourceTree = \"<group>\";\n"
        "\t\t}};".format(gid=t_group, t=TESTS, kids=kids))

    phase_files = "\n".join(
        "\t\t\t\t{} /* {} in Sources */,".format(uid("build", TESTS + "/" + n), n)
        for n in names)
    pbx = insert_before(pbx, "/* End PBXSourcesBuildPhase section */",
        "\t\t{sid} /* Sources */ = {{\n"
        "\t\t\tisa = PBXSourcesBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n{files}\n\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t}};".format(sid=t_sources, files=phase_files))

    pbx = insert_before(pbx, "/* End PBXFrameworksBuildPhase section */",
        "\t\t{fid} /* Frameworks */ = {{\n"
        "\t\t\tisa = PBXFrameworksBuildPhase;\n"
        "\t\t\tbuildActionMask = 2147483647;\n"
        "\t\t\tfiles = (\n\t\t\t);\n"
        "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
        "\t\t}};".format(fid=t_frameworks))

    pbx = insert_before(pbx, "/* End PBXNativeTarget section */",
        "\t\t{tid} /* {t} */ = {{\n"
        "\t\t\tisa = PBXNativeTarget;\n"
        "\t\t\tbuildConfigurationList = {cfg} /* Build configuration list for PBXNativeTarget \"{t}\" */;\n"
        "\t\t\tbuildPhases = (\n\t\t\t\t{sid} /* Sources */,\n\t\t\t\t{fid} /* Frameworks */,\n\t\t\t);\n"
        "\t\t\tbuildRules = (\n\t\t\t);\n"
        "\t\t\tdependencies = (\n\t\t\t\t{dep} /* PBXTargetDependency */,\n\t\t\t);\n"
        "\t\t\tname = {t};\n"
        "\t\t\tproductName = {t};\n"
        "\t\t\tproductReference = {pid} /* {t}.xctest */;\n"
        "\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";\n"
        "\t\t}};".format(tid=t_target, t=TESTS, cfg=t_cfglist, sid=t_sources,
                          fid=t_frameworks, dep=t_dep, pid=t_product))

    settings = (
        "\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;\n"
        "\t\t\t\tBUNDLE_LOADER = \"$(TEST_HOST)\";\n"
        "\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n"
        "\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = {dt};\n"
        "\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{bid}.tests\";\n"
        "\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";\n"
        "\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;\n"
        "\t\t\t\tSWIFT_VERSION = 5.0;\n"
        "\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";\n"
        "\t\t\t\tTEST_HOST = \"$(BUILT_PRODUCTS_DIR)/{app}.app/{app}\";\n"
    ).format(dt=DEPLOYMENT_TARGET, bid=BUNDLE_ID, app=APP)

    for cfg_id, name in ((t_debug, "Debug"), (t_release, "Release")):
        pbx = insert_before(pbx, "/* End XCBuildConfiguration section */",
            "\t\t{cid} /* {n} */ = {{\n"
            "\t\t\tisa = XCBuildConfiguration;\n"
            "\t\t\tbuildSettings = {{\n{s}\t\t\t}};\n"
            "\t\t\tname = {n};\n"
            "\t\t}};".format(cid=cfg_id, n=name, s=settings))

    pbx = insert_before(pbx, "/* End XCConfigurationList section */",
        "\t\t{cfg} /* Build configuration list for PBXNativeTarget \"{t}\" */ = {{\n"
        "\t\t\tisa = XCConfigurationList;\n"
        "\t\t\tbuildConfigurations = (\n"
        "\t\t\t\t{d} /* Debug */,\n\t\t\t\t{r} /* Release */,\n\t\t\t);\n"
        "\t\t\tdefaultConfigurationIsVisible = 0;\n"
        "\t\t\tdefaultConfigurationName = Release;\n"
        "\t\t}};".format(cfg=t_cfglist, t=TESTS, d=t_debug, r=t_release))

    pbx = pbx.replace("/* Begin PBXProject section */",
        "/* Begin PBXContainerItemProxy section */\n"
        "\t\t{proxy} /* PBXContainerItemProxy */ = {{\n"
        "\t\t\tisa = PBXContainerItemProxy;\n"
        "\t\t\tcontainerPortal = {proj} /* Project object */;\n"
        "\t\t\tproxyType = 1;\n"
        "\t\t\tremoteGlobalIDString = {app_target};\n"
        "\t\t\tremoteInfo = {app};\n"
        "\t\t}};\n"
        "/* End PBXContainerItemProxy section */\n\n"
        "/* Begin PBXTargetDependency section */\n"
        "\t\t{dep} /* PBXTargetDependency */ = {{\n"
        "\t\t\tisa = PBXTargetDependency;\n"
        "\t\t\ttarget = {app_target} /* {app} */;\n"
        "\t\t\ttargetProxy = {proxy} /* PBXContainerItemProxy */;\n"
        "\t\t}};\n"
        "/* End PBXTargetDependency section */\n\n"
        "/* Begin PBXProject section */".format(proxy=t_proxy, proj=project_id,
                                                app_target=app_target, app=APP, dep=t_dep))

    pbx = pbx.replace(
        "\t\t\t\t{} /* {}.app */,\n\t\t\t);\n\t\t\tname = Products;".format(
            uid("product", APP), APP),
        "\t\t\t\t{} /* {}.app */,\n\t\t\t\t{} /* {}.xctest */,\n\t\t\t);\n\t\t\tname = Products;".format(
            uid("product", APP), APP, t_product, TESTS))

    pbx = pbx.replace(
        "\t\t\t\t{} /* {} */,\n\t\t\t\t{} /* Products */,".format(
            uid("group", APP), APP, products_group),
        "\t\t\t\t{} /* {} */,\n\t\t\t\t{} /* {} */,\n\t\t\t\t{} /* Products */,".format(
            uid("group", APP), APP, t_group, TESTS, products_group))

    pbx = pbx.replace(
        "\t\t\t\t{} /* {} */,\n\t\t\t);\n\t\t}};\n/* End PBXProject section */".format(app_target, APP),
        "\t\t\t\t{} /* {} */,\n\t\t\t\t{} /* {} */,\n\t\t\t);\n\t\t}};\n/* End PBXProject section */".format(
            app_target, APP, t_target, TESTS))

    return pbx


def write_scheme(with_tests: bool):
    """Общая схема с действием «тесты».

    Своя, а не автоматическая: `xcodebuild test` ищет в схеме TestAction,
    а автосхема его может не содержать — и тесты молча не запускаются,
    сообщая «успех».
    """
    folder = os.path.join(PROJ_DIR, "xcshareddata", "xcschemes")
    os.makedirs(folder, exist_ok=True)
    testables = ""
    if with_tests:
        testables = (
            '      <TestableReference skipped = "NO">\n'
            '         <BuildableReference BuildableIdentifier = "primary" '
            'BlueprintIdentifier = "{tid}" BuildableName = "{t}.xctest" '
            'BlueprintName = "{t}" ReferencedContainer = "container:{app}.xcodeproj">'
            '</BuildableReference>\n'
            '      </TestableReference>\n'.format(tid=uid("target", TESTS), t=TESTS, app=APP)
        )

    scheme = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1420" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "{app}.app" BlueprintName = "{app}" ReferencedContainer = "container:{app}.xcodeproj"></BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
{testables}      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "{app}.app" BlueprintName = "{app}" ReferencedContainer = "container:{app}.xcodeproj"></BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference BuildableIdentifier = "primary" BlueprintIdentifier = "{app_target}" BuildableName = "{app}.app" BlueprintName = "{app}" ReferencedContainer = "container:{app}.xcodeproj"></BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug"></AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES"></ArchiveAction>
</Scheme>
""".format(app=APP, app_target=uid("target", APP), testables=testables)

    with open(os.path.join(folder, APP + ".xcscheme"), "w") as fh:
        fh.write(scheme)


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
				INFOPLIST_KEY_CFBundleLocalizations = "ru en";
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
			developmentRegion = ru;
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

    test_sources = sorted(
        name for name in os.listdir(TESTS_ROOT) if name.endswith(".swift")
    ) if os.path.isdir(TESTS_ROOT) else []
    if test_sources:
        pbx = add_tests(pbx, test_sources, target_id, project_id,
                        main_group_id, products_group_id)

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

    if test_sources:
        write_scheme(bool(test_sources))

    print("MAPA.xcodeproj пересобран: {} исходников, {} ресурсов, {} тестов"
          .format(len(sources), len(resources), len(test_sources)))


if __name__ == "__main__":
    generate()
