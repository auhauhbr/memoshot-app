allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    if (name == "receive_sharing_intent") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension> {
                // 1.9.0 declares API 37, but the stable Android SDK available
                // to this Flutter version is 36. The plugin uses no API 37-only
                // symbols, so keep it aligned with the application SDK.
                compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
