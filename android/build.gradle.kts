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
    
    // Force compileSdkVersion for all subprojects to fix older plugins incompatibility with AGP 8+
    project.plugins.withId("com.android.library") {
         val android = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
         android.compileSdk = 34 
         if (android.namespace == null) {
            android.namespace = project.group.toString()
         }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
