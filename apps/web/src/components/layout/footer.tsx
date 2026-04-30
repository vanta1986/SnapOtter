import { Globe, Moon, Sun } from "lucide-react";
import { useTheme } from "@/hooks/use-theme";
import { useTranslation } from "@/stores/locale-store";

export function Footer() {
  const { resolvedTheme, toggleTheme } = useTheme();
  const t = useTranslation().common;

  return (
    <div className="fixed bottom-4 right-4 flex items-center gap-2 z-50">
      <button
        type="button"
        onClick={toggleTheme}
        className="p-2 rounded-lg bg-card border border-border hover:bg-muted transition-colors"
        title={t.toggleTheme}
      >
        {resolvedTheme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
      </button>
      <button
        type="button"
        className="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-card border border-border hover:bg-muted transition-colors text-sm"
        title={t.language}
      >
        <Globe className="h-4 w-4" />
        {t.language}
      </button>
    </div>
  );
}
