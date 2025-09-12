#include <sourcemod>
#include <adminmenu>
#include <l4d2_source_keyvalues>
#include <left4dhooks>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3.0"

// --- 全局变量 ---
TopMenu g_TopMenu_AdminMenu;
Address g_pDirector;
Address g_pMatchExtL4D;
Handle g_hSDK_GetAllMissions;
StringMap g_smExclude;
ConVar g_cvMPGameMode;
char g_sCurrentGameMode[32];
bool g_bMapChanger_L4D2Changelevel;
bool g_bMapChanger_MapChanger;
bool g_bLastMenuIsOfficial[MAXPLAYERS + 1];

// --- 插件信息 ---
public Plugin myinfo = {
    name = "L4D2 Admin Mission Menu",
    author = "HoongDou ",
    description = "Adds a 'Switch Map/Mission' item to the admin menu for direct map changes.",
    version = PLUGIN_VERSION,
    url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

// --- Natives & 库 ---
native void L4D2_ChangeLevel(const char[] sMap);
native bool MC_SetNextMap(const char[] map);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    MarkNativeAsOptional("L4D2_ChangeLevel");
    MarkNativeAsOptional("MC_SetNextMap");
    RegPluginLibrary("l4d2_mm_adminmenu");
    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, "l4d2_changelevel")) {
        g_bMapChanger_L4D2Changelevel = true;
    } else if (StrEqual(name, "map_changer")) {
        g_bMapChanger_MapChanger = true;
    } else if (StrEqual(name, "adminmenu") && g_TopMenu_AdminMenu == null) {
        TopMenu topmenu = GetAdminTopMenu();
        if (topmenu != null) {
            OnAdminMenuReady(topmenu);
        }
    }
}

public void OnLibraryRemoved(const char[] name) {
    if (StrEqual(name, "adminmenu")) {
        g_TopMenu_AdminMenu = null;
    } else if (StrEqual(name, "l4d2_changelevel")) {
        g_bMapChanger_L4D2Changelevel = false;
    } else if (StrEqual(name, "map_changer")) {
        g_bMapChanger_MapChanger = false;
    }
}

// --- 插件核心功能 ---

public void OnPluginStart() {
    LoadTranslations("common.phrases");
    LoadTranslations("l4d2_mm_adminmenu.phrases");

    Init_GameData();

    g_smExclude = new StringMap();
    g_smExclude.SetValue("credits", 1);
    g_smExclude.SetValue("holdoutchallenge", 1);
    g_smExclude.SetValue("holdouttraining", 1);
    g_smExclude.SetValue("parishdash", 1);
    g_smExclude.SetValue("shootzones", 1);

    g_cvMPGameMode = FindConVar("mp_gamemode"); 
    g_cvMPGameMode.AddChangeHook(OnGameModeChanged);
    UpdateCurrentGameMode();

    TopMenu topmenu;
    if (LibraryExists("adminmenu") && (topmenu = GetAdminTopMenu()) != null) {
        OnAdminMenuReady(topmenu);
    }

    RegAdminCmd("sm_vpk_reload", Cmd_ReloadMissions, ADMFLAG_RCON, "Reloads VPKs and mission list.");
}

public void OnMapStart() {
    UpdateCurrentGameMode();
}

public void OnAdminMenuReady(Handle hTopMenu) {
    TopMenu topmenu = view_as<TopMenu>(hTopMenu);
    
    if (topmenu == null) {
        PrintToServer("[Admin Mission Menu] Error: TopMenu is null in OnAdminMenuReady.");
        return;
    }

    if (topmenu == g_TopMenu_AdminMenu) {
        return;
    }
    g_TopMenu_AdminMenu = topmenu;
    PrintToServer("[Admin Mission Menu] OnAdminMenuReady fired, registering menu item.");

    TopMenuObject server_commands = FindTopMenuCategory(topmenu, ADMINMENU_SERVERCOMMANDS);
    if (server_commands != INVALID_TOPMENUOBJECT) {
        AddToTopMenu(topmenu, "l4d2_switch_map", TopMenuObject_Item, AdminMenu_MainHandler, server_commands, "l4d2_switch_map_access", ADMFLAG_CHANGEMAP);
        PrintToServer("[Admin Mission Menu] Item 'l4d2_switch_map' added to menu.");
    } else {
        PrintToServer("[Admin Mission Menu] Warning: Could not find ADMINMENU_SERVERCOMMANDS category.");
    }
}

public void AdminMenu_MainHandler(TopMenu topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength) {
    if (action == TopMenuAction_DisplayOption) {
        Format(buffer, maxlength, "%T", "Switch Map/Mission", client);
    } else if (action == TopMenuAction_SelectOption) {
        Display_MapTypeMenu(client);
    }
}

/**
 * 菜单1: 选择地图类型 (官方/三方)
 */
void Display_MapTypeMenu(int client) {
    Menu menu = new Menu(MenuHandler_MapType);
    menu.SetTitle("%T", "Switch Map/Mission", client);

    char buffer[64];
    Format(buffer, sizeof(buffer), "%T", "Official Maps", client);
    menu.AddItem("official", buffer);
    Format(buffer, sizeof(buffer), "%T", "Addon Maps", client);
    menu.AddItem("addon", buffer);

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MapType(Menu menu, MenuAction action, int client, int choice) {
    if (action == MenuAction_Select) {
        char info[16];
        menu.GetItem(choice, info, sizeof(info));

        bool isOfficial = StrEqual(info, "official");
        Display_MissionListMenu(client, isOfficial);
    } else if (action == MenuAction_Cancel) {
        if (choice == MenuCancel_ExitBack) {
            DisplayTopMenu(g_TopMenu_AdminMenu, client, TopMenuPosition_LastCategory);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

/**
 * 菜单2: 显示战役列表 (根据官方/三方筛选)
 */
void Display_MissionListMenu(int client, bool official) {
    Menu menu = new Menu(MenuHandler_MissionList);
    menu.SetTitle("%T", official ? "Official Missions" : "Addon Missions", client);
    g_bLastMenuIsOfficial[client] = official;

    SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
    if (kvMissions.IsNull()) {
        delete menu;
        return;
    }

    char missionName[64], displayTitle[128];
    for (SourceKeyValues kvSub = kvMissions.GetFirstTrueSubKey(); !kvSub.IsNull(); kvSub = kvSub.GetNextTrueSubKey()) {
        kvSub.GetName(missionName, sizeof(missionName));
        if (g_smExclude.ContainsKey(missionName)) continue;

        char modePath[128];
        Format(modePath, sizeof(modePath), "modes/%s", g_sCurrentGameMode);
        if (kvSub.FindKey(modePath).IsNull()) continue;

        bool isBuiltIn = kvSub.GetInt("builtin") == 1;
        if (isBuiltIn == official) {
            if (TranslationPhraseExists(missionName)) {
				Format(displayTitle, sizeof(displayTitle), "%T", missionName, client);
				} else {
				strcopy(displayTitle, sizeof(displayTitle), missionName);
				}
            menu.AddItem(missionName, displayTitle);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_MissionList(Menu menu, MenuAction action, int client, int choice) {
    if (action == MenuAction_Select) {
        char missionName[64];
        menu.GetItem(choice, missionName, sizeof(missionName));
		
        Display_ChapterListMenu(client, missionName);
    } else if (action == MenuAction_Cancel) {
        if (choice == MenuCancel_ExitBack) {
            Display_MapTypeMenu(client);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}

/**
 * 菜单3: 显示章节列表
 */

void Display_ChapterListMenu(int client, const char[] missionName) {
    Menu menu = new Menu(MenuHandler_ChapterList);
    char title[128];
    if (TranslationPhraseExists(missionName)) {
		Format(title, sizeof(title), "%T", missionName, client);
	} else {
    strcopy(title, sizeof(title), missionName);
	}
    menu.SetTitle(title);

    SourceKeyValues kvMissions = SDKCall(g_hSDK_GetAllMissions, g_pMatchExtL4D);
    if (kvMissions.IsNull()) {
        delete menu;
        return;
    }

    char chapterPath[192];
    Format(chapterPath, sizeof(chapterPath), "%s/modes/%s", missionName, g_sCurrentGameMode);
    SourceKeyValues kvChapters = kvMissions.FindKey(chapterPath);
    if (kvChapters.IsNull()) {
        delete menu;
        return;
    }

    char mapName[64], displayMapName[128];
    for (SourceKeyValues kvMap = kvChapters.GetFirstTrueSubKey(); !kvMap.IsNull(); kvMap = kvMap.GetNextTrueSubKey()) {
        kvMap.GetString("Map", mapName, sizeof(mapName));
        if (IsMapValid(mapName)) {
            if (TranslationPhraseExists(mapName)) {
				Format(displayMapName, sizeof(displayMapName), "%T", mapName, client);
			} else {
				strcopy(displayMapName, sizeof(displayMapName), mapName);
			}
            menu.AddItem(mapName, displayMapName);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ChapterList(Menu menu, MenuAction action, int client, int choice) {
    if (action == MenuAction_Select) {
        char mapName[64];
        menu.GetItem(choice, mapName, sizeof(mapName));
        TriggerMapChange(mapName);
    } else if (action == MenuAction_Cancel) {
        if (choice == MenuCancel_ExitBack) {
            Display_MissionListMenu(client, g_bLastMenuIsOfficial[client]);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }
    return 0;
}


// --- 辅助函数 ---

void TriggerMapChange(const char[] map) {
    PrintToChatAll("\x04[SM]\x01 Admin is forcing a map change to \x03%s\x01.", map);
    DataPack dp = new DataPack();
    dp.WriteString(map);
    CreateTimer(2.0, Timer_ChangeMap, dp, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ChangeMap(Handle timer, DataPack dp) {
    dp.Reset();
    char mapName[64];
    dp.ReadString(mapName, sizeof(mapName));
    delete dp;

    if (g_bMapChanger_L4D2Changelevel && GetFeatureStatus(FeatureType_Native, "L4D2_ChangeLevel") == FeatureStatus_Available) {
        L4D2_ChangeLevel(mapName);
    } else if (g_bMapChanger_MapChanger && GetFeatureStatus(FeatureType_Native, "MC_SetNextMap") == FeatureStatus_Available) {
        MC_SetNextMap(mapName); 
        ServerCommand("changelevel %s", mapName);
    } else {
        ServerCommand("changelevel %s", mapName);
    }
    return Plugin_Stop;
}

Action Cmd_ReloadMissions(int client, int args) {
    PrintToChatAll("\x04[SM]\x01 Admin is reloading VPKs and mission list...");
    ServerCommand("update_addon_paths; mission_reload");
    ServerExecute();
    ReplyToCommand(client, "VPKs and missions reloaded.");
    return Plugin_Handled;
}

void OnGameModeChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    UpdateCurrentGameMode();
}

void UpdateCurrentGameMode() {
    g_cvMPGameMode.GetString(g_sCurrentGameMode, sizeof(g_sCurrentGameMode));
}

void Init_GameData() {
    GameData hGameData = new GameData("l4d2_map_vote");
    if (hGameData == null) {
        SetFailState("Failed to load 'l4d2_map_vote.txt' gamedata file. This plugin requires files from 'l4d2_map_vote' plugin.");
        return;
    }

    g_pDirector = hGameData.GetAddress("CDirector");
    if (g_pDirector == Address_Null) SetFailState("Failed to find address: 'CDirector'");

    g_pMatchExtL4D = hGameData.GetAddress("g_pMatchExtL4D");
    if (g_pMatchExtL4D == Address_Null) SetFailState("Failed to find address: 'g_pMatchExtL4D'");

    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetVirtual(0);
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    g_hSDK_GetAllMissions = EndPrepSDKCall();
    if (g_hSDK_GetAllMissions == null) SetFailState("Failed to create SDKCall: 'MatchExtL4D::GetAllMissions'");

    delete hGameData;
}
