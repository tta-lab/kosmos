{pkgsUnstable, ...}: let
  androidPkgs = import pkgsUnstable.path {
    inherit (pkgsUnstable.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
    };
  };
  sdk =
    (androidPkgs.androidenv.composeAndroidPackages {
      cmdLineToolsVersion = "22.0";
      platformToolsVersion = "37.0.1";
      buildToolsVersions = ["35.0.0"];
      platformVersions = ["36"];
      toolsVersion = null;
      includeCmake = false;
    }).androidsdk;
in {
  environment.systemPackages = [
    pkgsUnstable.jdk21
    sdk
  ];

  home-manager.users.neil.home.sessionVariables = {
    JAVA_HOME = "${pkgsUnstable.jdk21}";
    ANDROID_HOME = "${sdk}/libexec/android-sdk";
  };
}
