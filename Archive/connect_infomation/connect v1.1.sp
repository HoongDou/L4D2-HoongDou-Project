#pragma semicolon 1
#define DEBUG
#include <sourcemod>
#include <sdktools>
#include <geoip>
#define PLUGIN_VERSION "1.5"
/*changelog:
v1.5：fixed bugs when kicking bot shows the infomation.
v1.4: fixed team infected leaving not showing the infomation.
v1.3: added leaving reason & showing crashed.Remove showing city(lots of bugs,maybe fixed in ~)
v1.2: added showing city.

/*
char ClientIP[36];
char country[45];
char code2[3];
//char city[64];
new String:user_steamid[21];

public Plugin:myinfo =
{
name = "Connect & Disconnect Info",
author = "Hoongdou",
description = "Show SteamID 、Country and IP while Ccnnecting,when leaving the game would print the reasons.",
version = PLUGIN_VERSION,
url = ""
};

public OnPluginStart() {
    HookEvent("player_disconnect", playerDisconnect, EventHookMode_Pre);
}


public void OnClientAuthorized(int client, const char[] auth) 
//public void OnClientPutInServer(client)
{
    GetClientIP(client, ClientIP, 20, true);
    GetClientAuthId(client, AuthId_Steam2, user_steamid, sizeof(user_steamid));
    GeoipCountry(ClientIP, country, sizeof(country));
    GeoipCode2(ClientIP, code2);
	//GeoipCity(ClientIP, city, sizeof(city));
    if (!IsFakeClient(client))
	{
	    PrintToChatAll("\x05%N \x03<%s>\x01connected. \nFrom\x05[%s]\x04%s", client, user_steamid, code2, ClientIP);
	}
}

public playerDisconnect(Handle:event, const String:name[], bool:dontBroadcast) {
    SetEventBroadcast(event, true);
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients) return;
    decl String:steamId[64];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    //GetClientAuthString(client, steamId, sizeof(steamId));
    if (strcmp(steamId, "BOT") == 0) return;

    decl String:reason[128];
    GetEventString(event, "reason", reason, sizeof(reason));
    decl String:playerName[128];
    GetEventString(event, "name", playerName, sizeof(playerName));
    decl String:timedOut[256];
    Format(timedOut, sizeof(timedOut), "%s timed out", playerName);
    PrintToChatAll("\x05%s \x03<%s> \x01disconnected.\n\x05Reason: \x04%s", playerName, steamId, reason);
    LogMessage("[Connect Info] Player %s <%s> left the game: %s", playerName, steamId, reason);
	
    // If the leaving player crashed, pause.
    if (strcmp(reason, timedOut) == 0 || strcmp(reason, "No Steam logon") == 0) {
            PrintToChatAll("\x05%s <%s> disconnected.\x01Reason:crashed.", playerName, steamId);
    }
}
	
//no reason:just print disconnected.
/*public OnClientDisconnect(client)  
{
	if (!IsFakeClient(client))
	{
		PrintToChatAll("\x05%N \x01disconnected.", client);
	}
}
*/
