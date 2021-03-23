
#pragma semicolon 1
#include <sourcemod>

#define PLUGIN_VERSION          "1.0.0"

#define FCVAR_VERSION           FCVAR_NOTIFY|FCVAR_DONTRECORD|FCVAR_CHEAT

static String:szCurrentmap[99];

public Plugin:myinfo = {
    name = "Restart Map",
    author = "hoongdou",
    description = "Restart the current map",
    version = PLUGIN_VERSION,
    url = "http://steamcommunity.com/groups/tf2data"
};

public OnPluginStart()
{
    RegAdminCmd("sm_restartmap", Cmd_MapRestart, ADMFLAG_CHANGEMAP);
    CreateConVar("sv_restartmap_version", PLUGIN_VERSION, "Restart Map Version", FCVAR_VERSION);
}

public OnMapStart()
{
    GetCurrentMap(szCurrentmap, sizeof(szCurrentmap));
}

public Action:Cmd_MapRestart(iClient, iArgc)
{
    ForceChangeLevel(szCurrentmap, "[SM] Restarting the map.");
    return Plugin_Handled;
}