import React, { useEffect } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Image from "@tiptap/extension-image";
import Placeholder from "@tiptap/extension-placeholder";
import api, { formatApiError } from "@/lib/api";
import { toast } from "sonner";
import { Bold, Italic, List, ListOrdered, Image as ImageIcon, Undo2, Redo2, Heading2, Code } from "lucide-react";

export default function RichEditor({ value = "", onChange, placeholder = "Type or paste from Word…" }) {
  const editor = useEditor({
    extensions: [
      StarterKit,
      Image.configure({ inline: false, allowBase64: true }),
      Placeholder.configure({ placeholder }),
    ],
    content: value || "",
    onUpdate: ({ editor }) => onChange?.(editor.getHTML()),
    editorProps: {
      attributes: {
        class: "prose-sm max-w-none focus:outline-none min-h-[140px] px-4 py-3",
      },
    },
  });

  useEffect(() => {
    if (editor && value && editor.getHTML() !== value) {
      editor.commands.setContent(value, false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  const uploadImage = async (e) => {
    const file = e.target.files?.[0];
    if (!file || !editor) return;
    const fd = new FormData();
    fd.append("file", file);
    try {
      const r = await api.post("/api/uploads/image", fd, { headers: { "Content-Type": "multipart/form-data" } });
      const url = `${process.env.REACT_APP_BACKEND_URL}${r.data.url}`;
      editor.chain().focus().setImage({ src: url }).run();
    } catch (err) {
      toast.error(formatApiError(err));
    }
    e.target.value = "";
  };

  if (!editor) return null;

  const Btn = ({ onClick, active, label, testid, children }) => (
    <button
      type="button"
      onClick={onClick}
      title={label}
      data-testid={testid}
      className={`p-1.5 rounded-md hover:bg-slate-100 transition-colors ${active ? "bg-[#0F1B4C] text-white hover:bg-[#0F1B4C]" : "text-[#334155]"}`}
    >
      {children}
    </button>
  );

  return (
    <div className="rounded-xl border border-slate-200 bg-white overflow-hidden">
      <div className="flex flex-wrap items-center gap-1 border-b border-slate-100 bg-slate-50 px-2 py-1.5">
        <Btn onClick={() => editor.chain().focus().toggleBold().run()} active={editor.isActive("bold")} label="Bold" testid="editor-bold"><Bold size={14} /></Btn>
        <Btn onClick={() => editor.chain().focus().toggleItalic().run()} active={editor.isActive("italic")} label="Italic" testid="editor-italic"><Italic size={14} /></Btn>
        <Btn onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()} active={editor.isActive("heading", { level: 3 })} label="Heading" testid="editor-h"><Heading2 size={14} /></Btn>
        <Btn onClick={() => editor.chain().focus().toggleBulletList().run()} active={editor.isActive("bulletList")} label="Bullets" testid="editor-ul"><List size={14} /></Btn>
        <Btn onClick={() => editor.chain().focus().toggleOrderedList().run()} active={editor.isActive("orderedList")} label="Numbered" testid="editor-ol"><ListOrdered size={14} /></Btn>
        <Btn onClick={() => editor.chain().focus().toggleCode().run()} active={editor.isActive("code")} label="Code" testid="editor-code"><Code size={14} /></Btn>
        <div className="w-px h-5 bg-slate-200 mx-1" />
        <label className="p-1.5 rounded-md hover:bg-slate-100 cursor-pointer text-[#334155]" title="Insert image">
          <input type="file" accept="image/*" onChange={uploadImage} className="hidden" data-testid="editor-image-input" />
          <ImageIcon size={14} />
        </label>
        <div className="ml-auto flex items-center gap-1">
          <Btn onClick={() => editor.chain().focus().undo().run()} label="Undo" testid="editor-undo"><Undo2 size={14} /></Btn>
          <Btn onClick={() => editor.chain().focus().redo().run()} label="Redo" testid="editor-redo"><Redo2 size={14} /></Btn>
        </div>
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
