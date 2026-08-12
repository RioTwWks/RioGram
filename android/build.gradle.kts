import com.android.build.gradle.BaseExtension

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
    fun Project.forceCompileSdk36() {
        extensions.findByType(BaseExtension::class.java)?.apply {
            compileSdkVersion(36)
        }
    }

    // plugins.withId срабатывает до build.gradle плагина; afterEvaluate — после.
    // evaluationDependsOn может уже оценить subproject → проверяем state.executed.
    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate { forceCompileSdk36() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
