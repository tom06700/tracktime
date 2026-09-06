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
// file_picker 11 skips KGP for every AGP 9 build, even when built-in Kotlin
// is disabled. Apply its upstream beta.3 compatibility fix without changing
// the stable file-picking API or iOS minimum version.
subprojects {
    if (name == "file_picker") {
        apply(from = rootProject.file("file_picker_compat.gradle"))
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
