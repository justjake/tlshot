import { useCallback, useEffect, useState } from "react";
import { Editor, TLOnMountHandler, Tldraw } from "tldraw";
import { bridge } from "./Bridge";

function App() {
  const [editor, setEditor] = useState<Editor | null>(null);

  useEffect(() => {
    if (!editor) return;
    console.log("Editor mounted", editor);
    console.log("current user prefs", editor.user.getUserPreferences());
    editor.user.updateUserPreferences({ colorScheme: bridge.env.theme });
  }, [editor]);

  return (
    <div style={{ position: "fixed", inset: 0 }}>
      <Tldraw inferDarkMode onMount={setEditor} />
    </div>
  );
}

export default App;
