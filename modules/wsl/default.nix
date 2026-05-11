{ ... }:

{
  wsl = {
    enable = true;
    defaultUser = "neil";

    interop = {
      includePath = false;
    };

    wslConf = {
      interop.appendWindowsPath = false;
    };
  };
}
