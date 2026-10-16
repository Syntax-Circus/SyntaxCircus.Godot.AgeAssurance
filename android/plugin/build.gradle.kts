plugins { id("com.android.library"); id("org.jetbrains.kotlin.android") }
android {
    namespace = "com.syntaxcircus.ageassurance"
    compileSdk = 36
    defaultConfig { minSdk = 24; consumerProguardFiles("consumer-rules.pro") }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}
dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
    implementation("com.google.android.play:age-signals:0.0.4")
    testImplementation("junit:junit:4.13.2")
}
