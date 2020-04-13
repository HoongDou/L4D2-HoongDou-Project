#pragma semicolon 1
#define DEBUG
#include <sourcemod>
#include <sdktools>
#include <geoip>
#define PLUGIN_VERSION "1.1"

char country[45];
char code2[3];
char city[64];

public Plugin:myinfo =
{
name = "Connect info",
author = "Hoongdou",
description = "Print SteamID and IP in chat",
version = PLUGIN_VERSION,
url = ""
};
	
public void OnClientAuthorized(int client, const char[] auth) 
//public void OnClientPutInServer(client)
{
	char ClientIP[36];
	new String:user_steamid[21];
	GetClientIP(client, ClientIP, 20, true);
	GetClientAuthId(client, AuthId_Steam2, user_steamid, sizeof(user_steamid));
	GeoipCountry(ClientIP, country, sizeof(country));
	GeoipCode2(ClientIP, code2);
	//GeoipCity(ClientIP, city, sizeof(city));
	if (!IsFakeClient(client))
	{
		PrintToChatAll("\x05%N \x03<%s>\x01connected \nFrom\x05[%s]\x04%s", client, user_steamid, code2, ClientIP);
	}
}

public OnClientDisconnect(client)
{
	if (!IsFakeClient(client))
	{
		PrintToChatAll("\x05%N \x01disconnected.", client);
	}
}
