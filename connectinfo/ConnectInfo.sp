#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <ripext>

#define DEBUG
#define CONFIG_FILE "cfg/sourcemod/ip_data_api.cfg"

char g_ClientIPs[MAXPLAYERS+1][36];
ConVar g_hAPIKey;
ConVar g_hGeocodeAPIKey;

// 使用全局数组存储待处理的客户端信息
enum struct ClientInfo {
    int client;
    char steamID[32];
    char countryCode[8];
    char ipAddress[32];
}

ClientInfo g_PendingClients[MAXPLAYERS+1]; // 全局数组存储客户端信息

public Plugin myinfo = {
    name = "Connect info",
    author = "HoongDou",
    description = "Print SteamID and IP in chat via HTTP requests with REST in Pawn",
    version = "2.2", 
    url = ""
};

public void OnPluginStart() {
    AutoExecConfig(true, "ip_data_api");
    g_hAPIKey = CreateConVar("sm_ipdata_apikey", "", "API key for ipdata.co", FCVAR_PROTECTED | FCVAR_NOTIFY);
    g_hGeocodeAPIKey = CreateConVar("sm_geocode_apikey", "", "API key for geocode.maps.co", FCVAR_PROTECTED | FCVAR_NOTIFY);
    
    g_hAPIKey.AddChangeHook(OnAPIKeyChanged);
    g_hGeocodeAPIKey.AddChangeHook(OnGeocodeAPIKeyChanged);
    
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int client) {
    char apiKey[64];
    g_hAPIKey.GetString(apiKey, sizeof(apiKey));

    if (!IsFakeClient(client) && strlen(apiKey) > 0) {
        char ipAddress[32];
        GetClientIP(client, ipAddress, sizeof(ipAddress));
        
        strcopy(g_ClientIPs[client], sizeof(g_ClientIPs[]), ipAddress);
        
        char url[512];
        Format(url, sizeof(url), "%s?api-key=%s", ipAddress, apiKey);

        HTTPClient clientObj = new HTTPClient("https://api.ipdata.co");
        clientObj.SetHeader("User-Agent", "Mozilla/5.0 (compatible; MyBot/1.0)");

        clientObj.Get(url, HttpRequestCallback, client);
    }
}

public void HttpRequestCallback(HTTPResponse response, int client) {
    if (response.Status != HTTPStatus_OK) {
        PrintToChat(client, "HTTP request failed with status: %d", response.Status);
        
        if (response.Status == HTTPStatus_BadRequest) {
            char responseBody[4096];
            response.Data.ToString(responseBody, sizeof(responseBody));
            JSONObject jsonObject = JSONObject.FromString(responseBody);
            if (jsonObject != null) {
                char errorMessage[256];
                jsonObject.GetString("message", errorMessage, sizeof(errorMessage));
                LogError("HTTP 400 Bad Request: %s", errorMessage);
                delete jsonObject;
            }
        }
        return;
    }

    char responseBody[4096];
    response.Data.ToString(responseBody, sizeof(responseBody));

    JSONObject jsonObject = JSONObject.FromString(responseBody);
    if (jsonObject == null) {
        PrintToChat(client, "Failed to parse JSON response.");
        return;
    }

    char countryCode[8], city[64];
    jsonObject.GetString("country_code", countryCode, sizeof(countryCode));
    jsonObject.GetString("city", city, sizeof(city));
    
    char userSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, userSteamID, sizeof(userSteamID));

    if (strlen(city) == 0 || StrEqual(city, "null", false)) {
        float latitude = jsonObject.GetFloat("latitude");
        float longitude = jsonObject.GetFloat("longitude");
        
        delete jsonObject;
        
        if (latitude != 0.0 && longitude != 0.0) {
            char geocodeAPIKey[64];
            g_hGeocodeAPIKey.GetString(geocodeAPIKey, sizeof(geocodeAPIKey));
            
            if (strlen(geocodeAPIKey) > 0) {
                // 将客户端信息存储到全局数组
                g_PendingClients[client].client = client;
                strcopy(g_PendingClients[client].steamID, sizeof(g_PendingClients[].steamID), userSteamID);
                strcopy(g_PendingClients[client].countryCode, sizeof(g_PendingClients[].countryCode), countryCode);
                strcopy(g_PendingClients[client].ipAddress, sizeof(g_PendingClients[].ipAddress), g_ClientIPs[client]);
                
                char geocodeUrl[512];
                Format(geocodeUrl, sizeof(geocodeUrl), "/reverse?lat=%.10f&lon=%.10f&api_key=%s", latitude, longitude, geocodeAPIKey);
                
                HTTPClient geocodeClient = new HTTPClient("https://geocode.maps.co");
                geocodeClient.SetHeader("User-Agent", "Mozilla/5.0 (compatible; MyBot/1.0)");
                
                geocodeClient.Get(geocodeUrl, GeocodeRequestCallback, client);
                
                return;
            }
        }
        
        strcopy(city, sizeof(city), "Unknown");
    } else {
        delete jsonObject;
    }
    
    PrintToChatAll("\x05%N \x03<%s>\x01 connected \nFrom\x05[\x03%s \x01 %s\x05]\x04 %s", client, userSteamID, countryCode, city, g_ClientIPs[client]);
}

// 修改回调函数 - 直接使用全局数组，不复制结构体
public void GeocodeRequestCallback(HTTPResponse response, int client) {
    char city[64] = "Unknown";
    
    if (response.Status == HTTPStatus_OK) {
        char responseBody[4096];
        response.Data.ToString(responseBody, sizeof(responseBody));
        
        JSONObject jsonObject = JSONObject.FromString(responseBody);
        if (jsonObject != null) {
            JSONObject address = view_as<JSONObject>(jsonObject.Get("address"));
            if (address != null) {
                address.GetString("state", city, sizeof(city));
                
                if (strlen(city) == 0) {
                    address.GetString("city", city, sizeof(city));
                }
                
                if (strlen(city) == 0) {
                    address.GetString("district", city, sizeof(city));
                }
                
                delete address;
            }
            delete jsonObject;
        }
    }
    
    if (strlen(city) == 0) {
        strcopy(city, sizeof(city), "Unknown");
    }
    
    // 直接使用全局数组中的数据
    PrintToChatAll("\x05%N \x03<%s>\x01 connected \nFrom\x05[\x03%s \x01 %s\x05]\x04 %s", 
                   g_PendingClients[client].client, 
                   g_PendingClients[client].steamID, 
                   g_PendingClients[client].countryCode, 
                   city, 
                   g_PendingClients[client].ipAddress);
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    SetEventBroadcast(event, true);
    
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients || IsFakeClient(client)) {
        return;
    }
    
    char steamId[32];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    
    if (StrEqual(steamId, "BOT", false)) {
        return;
    }
    
    char reason[128];
    GetEventString(event, "reason", reason, sizeof(reason));
    char playerName[64];
    GetEventString(event, "name", playerName, sizeof(playerName));
    
    char reasonColor[8] = "\x04";
    char statusMessage[128] = "";
    
    if (StrContains(reason, "timed out", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07");
        strcopy(statusMessage, sizeof(statusMessage), "\x05 crashed");
    }
    else if (StrEqual(reason, "No Steam logon", false)) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07");
        strcopy(statusMessage, sizeof(statusMessage), "\x05 crashed");
    }
    else if (StrEqual(reason, "Disconnect by user.", false)) {
        strcopy(reasonColor, sizeof(reasonColor), "\x03");
        strcopy(statusMessage, sizeof(statusMessage), "\x03 left");
    }
    else if (StrContains(reason, "Connection lost", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x09");
        strcopy(statusMessage, sizeof(statusMessage), "\x09 lost connection");
    }
    else if (StrContains(reason, "kicked", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07");
        strcopy(statusMessage, sizeof(statusMessage), "\x07 was kicked");
    }
    
    if (strlen(statusMessage) > 0) {
        PrintToChatAll("\x05%s \x03<%s> \x01 disconnected (%s).\n\x05 Reason: %s%s", 
                       playerName, steamId, statusMessage, reasonColor, reason);
    } else {
        PrintToChatAll("\x05%s \x03<%s> \x01 disconnected.\n\x05 Reason: %s%s", 
                       playerName, steamId, reasonColor, reason);
    }
    
    LogMessage("[Connect Info] Player %s <%s> left the game: %s", playerName, steamId, reason);
    
    if (StrContains(statusMessage, "crashed", false) != -1) {
        PrintToChatAll("\x05%s \x01 crashed!", playerName);
    }
}

public void OnAPIKeyChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    LogMessage("IP API key changed from '%s' to '%s'", oldValue, newValue);
}

public void OnGeocodeAPIKeyChanged(ConVar convar, const char[] oldValue, const char[] newValue) {
    LogMessage("Geocode API key changed from '%s' to '%s'", oldValue, newValue);
}

public void OnClientDisconnect(int client) {
    if (!IsFakeClient(client)) {
        g_ClientIPs[client][0] = '\0';
        // 清理待处理的客户端信息
        g_PendingClients[client].client = 0;
        g_PendingClients[client].steamID[0] = '\0';
        g_PendingClients[client].countryCode[0] = '\0';
        g_PendingClients[client].ipAddress[0] = '\0';
    }
}
