import type { LucideIcon } from "lucide-react";
import { FolderOpen, Grid3x3, HelpCircle, LayoutGrid, Settings, Workflow } from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { cn } from "@/lib/utils";
import { useTranslation } from "@/stores/locale-store";

interface SidebarItem {
  icon: LucideIcon;
  labelKey: keyof ReturnType<typeof useTranslation>["nav"];
  href?: string;
}

export function Sidebar({
  onSettingsClick,
  onHelpClick,
  onNavClick,
  expanded = false,
}: {
  onSettingsClick: () => void;
  onHelpClick: () => void;
  onNavClick?: () => void;
  expanded?: boolean;
}) {
  const t = useTranslation().nav;
  const location = useLocation();

  const topItems: SidebarItem[] = [
    { icon: LayoutGrid, labelKey: "tools", href: "/" },
    { icon: Grid3x3, labelKey: "reader", href: "/fullscreen" },
    { icon: Workflow, labelKey: "automate", href: "/automate" },
    { icon: FolderOpen, labelKey: "files", href: "/files" },
  ];

  const bottomItems: SidebarItem[] = [
    { icon: HelpCircle, labelKey: "help" },
    { icon: Settings, labelKey: "settings" },
  ];

  const getLabel = (key: keyof typeof t): string => {
    return t[key] || key;
  };

  const renderItem = (item: SidebarItem, isActive: boolean) => {
    const label = getLabel(item.labelKey);
    const content = expanded ? (
      <div
        className={cn(
          "flex items-center gap-3 px-4 py-2.5 rounded-lg cursor-pointer transition-colors",
          isActive
            ? "bg-primary text-primary-foreground"
            : "text-muted-foreground hover:bg-muted hover:text-foreground",
        )}
      >
        <item.icon className="h-5 w-5" />
        <span className="text-sm font-medium">{label}</span>
      </div>
    ) : (
      <div
        className={cn(
          "flex flex-col items-center gap-1 p-2 rounded-lg cursor-pointer transition-colors",
          isActive
            ? "bg-primary text-primary-foreground"
            : "text-muted-foreground hover:bg-muted hover:text-foreground",
        )}
      >
        <item.icon className="h-6 w-6" />
        <span className="text-[10px] font-medium">{label}</span>
      </div>
    );

    if (item.labelKey === "settings") {
      return (
        <button key={item.labelKey} type="button" onClick={onSettingsClick} className="w-full">
          {content}
        </button>
      );
    }
    if (item.labelKey === "help") {
      return (
        <button key={item.labelKey} type="button" onClick={onHelpClick} className="w-full">
          {content}
        </button>
      );
    }
    return (
      <Link key={item.labelKey} to={item.href || "/"} onClick={onNavClick}>
        {content}
      </Link>
    );
  };

  if (expanded) {
    return (
      <div className="flex flex-col p-3 gap-1">
        {topItems.map((item) => renderItem(item, location.pathname === item.href))}
        <div className="border-t border-border my-2" />
        {bottomItems.map((item) => renderItem(item, false))}
      </div>
    );
  }

  return (
    <aside className="flex flex-col items-center w-16 bg-sidebar border-r border-border py-3 gap-1 shrink-0">
      <div className="flex flex-col gap-1 flex-1">
        {topItems.map((item) => renderItem(item, location.pathname === item.href))}
      </div>
      <div className="border-t border-border w-10 my-2" />
      <div className="flex flex-col gap-1">
        {bottomItems.map((item) => renderItem(item, false))}
      </div>
    </aside>
  );
}