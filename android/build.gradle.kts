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
    val configureNamespace = {
        val android = extensions.findByName("android")
        if (android != null) {
            val getNamespace = android.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val setNamespace = android.javaClass.methods.firstOrNull { it.name == "setNamespace" && it.parameterTypes.size == 1 }
            if (getNamespace != null && setNamespace != null) {
                val currentNamespace = getNamespace.invoke(android)
                if (currentNamespace == null) {
                    setNamespace.invoke(android, "com.example.${project.name.replace("-", "_")}")
                }
            }
        }
    }
    if (state.executed) {
        configureNamespace()
    } else {
        afterEvaluate { configureNamespace() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
