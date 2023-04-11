import {
  installExtension,
  REACT_DEVELOPER_TOOLS,
} from "electron-extension-installer";

export function installDevtoolsExtensions() {
  return installExtension(REACT_DEVELOPER_TOOLS, {
    loadExtensionOptions: {
      allowFileAccess: true,
    },
  });
}
