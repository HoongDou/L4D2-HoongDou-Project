#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <ripext>

#define DEBUG
#define CONFIG_FILE "cfg/sourcemod/ip_data_api.cfg" // 配置文件路径

char g_ClientIPs[MAXPLAYERS+1][36]; // 用于存储每位客户端的 IP 地址
ConVar g_hAPIKey; // 用于存储 IP API 密钥配置的 ConVar
ConVar g_hGeocodeAPIKey; // 用于存储 Geocode API 密钥配置的 ConVar

// 结构体用于存储客户端信息，传递给第二次API调用
enum struct ClientInfo {
    int client;
    char steamID[32];
    char countryCode[8];
    char ipAddress[32];
}

public Plugin myinfo = {
    name = "Connect info",
    author = "HoongDou",
    description = "Print SteamID and IP in chat via HTTP requests with REST in Pawn",
    version = "2.0", 
    url = ""
};

// 插件初始化
public void OnPluginStart() {
    AutoExecConfig(true, "ip_data_api");
    g_hAPIKey = CreateConVar("sm_ipdata_apikey", "", "API key for ipdata.co", FCVAR_PROTECTED | FCVAR_NOTIFY);
    g_hGeocodeAPIKey = CreateConVar("sm_geocode_apikey", "", "API key for geocode.maps.co", FCVAR_PROTECTED | FCVAR_NOTIFY);
    
    // 绑定变量变动时的回调函数
    HookConVarChange(g_hAPIKey, OnAPIKeyChanged);
    HookConVarChange(g_hGeocodeAPIKey, OnGeocodeAPIKeyChanged);
    
    // 添加玩家离开事件监听
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientPutInServer(int client) {
    char apiKey[64];
    GetConVarString(g_hAPIKey, apiKey, sizeof(apiKey)); // 获取 API 密钥

    // 如果不是AI且 API 密钥已正确配置
    if (!IsFakeClient(client) && strlen(apiKey) > 0) {
        char ipAddress[32];
        GetClientIP(client, ipAddress, sizeof(ipAddress)); // 获取客户端的 IP 地址
        
        // 将客户端 IP 存储到全局数组中方便后续读取
        strcopy(g_ClientIPs[client], sizeof(g_ClientIPs[]), ipAddress);
        char url[512];
        Format(url, sizeof(url), "%s?api-key=%s", ipAddress, apiKey); // 格式化生成 API 请求的 URL

        // HTTP 请求客户端初始化，设置请求的UA头
        HTTPClient clientObj = new HTTPClient("https://api.ipdata.co");
        clientObj.SetHeader("User-Agent", "Mozilla/5.0 (compatible; MyBot/1.0)");

        // 发送 HTTP GET 请求，携带 URL 和回调函数
        clientObj.Get(url, HttpRequestCallback, client);
    }
}

// HTTP 请求回调处理
public void HttpRequestCallback(HTTPResponse response, int client) {
    // 检查 HTTP 请求的返回状态
    if (response.Status != HTTPStatus_OK) {
        // 请求失败时在客户端聊天中输出错误状态
        PrintToChat(client, "HTTP request failed with status: %d", response.Status);
        
        // 如果是错误请求，解析并记录错误信息
        if (response.Status == HTTPStatus_BadRequest) {
            char responseBody[4096];
            response.Data.ToString(responseBody, sizeof(responseBody)); // 将响应数据转换为字符串
            JSONObject jsonObject = JSONObject.FromString(responseBody); // 解析 JSON 对象
            if (jsonObject != null) {
                char errorMessage[256];
                jsonObject.GetString("message", errorMessage, sizeof(errorMessage)); // 获取错误消息
                LogError("HTTP 400 Bad Request: %s", errorMessage); // 记录错误日志
                delete jsonObject; // 释放 JSON 对象
            }
        }
        return; // 处理结束，返回
    }

    char responseBody[4096];
    response.Data.ToString(responseBody, sizeof(responseBody)); // 将响应数据转换为字符串

    JSONObject jsonObject = JSONObject.FromString(responseBody); // 解析 JSON 响应
    if (jsonObject == null) {
        PrintToChat(client, "Failed to parse JSON response."); // 解析失败时输出错误信息
        return;
    }

    char countryCode[8], city[64];
    jsonObject.GetString("country_code", countryCode, sizeof(countryCode)); // 提取国家码
    jsonObject.GetString("city", city, sizeof(city)); // 提取城市名称
    
    char userSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, userSteamID, sizeof(userSteamID)); // 获取客户端的 Steam ID

    // 检查city是否为null或空字符串
    if (strlen(city) == 0 || StrEqual(city, "null", false)) {
        // 获取经纬度信息
        float latitude = jsonObject.GetFloat("latitude");
        float longitude = jsonObject.GetFloat("longitude");
        
        // 释放第一次请求的JSON对象
        delete jsonObject;
        
        // 如果经纬度有效，进行第二次API查询
        if (latitude != 0.0 && longitude != 0.0) {
            char geocodeAPIKey[64];
            GetConVarString(g_hGeocodeAPIKey, geocodeAPIKey, sizeof(geocodeAPIKey));
            
            if (strlen(geocodeAPIKey) > 0) {
                // 创建客户端信息结构体
                ClientInfo clientInfo;
                clientInfo.client = client;
                strcopy(clientInfo.steamID, sizeof(clientInfo.steamID), userSteamID);
                strcopy(clientInfo.countryCode, sizeof(clientInfo.countryCode), countryCode);
                strcopy(clientInfo.ipAddress, sizeof(clientInfo.ipAddress), g_ClientIPs[client]);
                
                // 构建geocode API URL
                char geocodeUrl[512];
                Format(geocodeUrl, sizeof(geocodeUrl), "/reverse?lat=%.10f&lon=%.10f&api_key=%s", latitude, longitude, geocodeAPIKey);
                
                // 发送第二次HTTP请求
                HTTPClient geocodeClient = new HTTPClient("https://geocode.maps.co");
                geocodeClient.SetHeader("User-Agent", "Mozilla/5.0 (compatible; MyBot/1.0)");
                geocodeClient.Get(geocodeUrl, GeocodeRequestCallback, clientInfo);
                
                return; // 等待第二次请求完成
            }
        }
        
        // 如果无法进行第二次查询，使用默认的未知城市信息
        strcopy(city, sizeof(city), "Unknown");
    } else {
        // 释放JSON对象
        delete jsonObject;
    }
    
    // 直接显示连接信息（当city不为null时）
    PrintToChatAll("\x05%N \x03<%s>\x01 connected \nFrom\x05[\x03%s \x01 %s\x05]\x04 %s", client, userSteamID, countryCode, city, g_ClientIPs[client]);
}

// Geocode API 回调处理
public void GeocodeRequestCallback(HTTPResponse response, ClientInfo clientInfo) {
    char city[64] = "Unknown";
    
    if (response.Status == HTTPStatus_OK) {
        char responseBody[4096];
        response.Data.ToString(responseBody, sizeof(responseBody));
        
        JSONObject jsonObject = JSONObject.FromString(responseBody);
        if (jsonObject != null) {
            // 尝试获取address对象
            JSONObject address = view_as<JSONObject>(jsonObject.Get("address"));
            if (address != null) {
                // 首先尝试获取state字段
                address.GetString("state", city, sizeof(city));
                
                // 如果state为空，尝试获取city字段
                if (strlen(city) == 0) {
                    address.GetString("city", city, sizeof(city));
                }
                
                // 如果还是为空，尝试获取district字段
                if (strlen(city) == 0) {
                    address.GetString("district", city, sizeof(city));
                }
                
                delete address;
            }
            delete jsonObject;
        }
    }
    
    // 如果city仍然为空，设置默认值
    if (strlen(city) == 0) {
        strcopy(city, sizeof(city), "Unknown");
    }
    
    // 显示最终的连接信息
    PrintToChatAll("\x05%N \x03<%s>\x01 connected \nFrom\x05[\x03%s \x01 %s\x05]\x04 %s", 
                   clientInfo.client, clientInfo.steamID, clientInfo.countryCode, city, clientInfo.ipAddress);
}

// 玩家离开事件处理
public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
    SetEventBroadcast(event, true);
    
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    if (client <= 0 || client > MaxClients || IsFakeClient(client)) {
        return;
    }
    
    char steamId[32];
    GetClientAuthId(client, AuthId_Steam2, steamId, sizeof(steamId));
    
    // 跳过BOT
    if (StrEqual(steamId, "BOT", false)) {
        return;
    }
    
    char reason[128];
    GetEventString(event, "reason", reason, sizeof(reason));
    char playerName[64];
    GetEventString(event, "name", playerName, sizeof(playerName));
    
    // 格式化离开原因的显示
    char reasonColor[8] = "\x04"; // 默认橙色
    char statusMessage[128] = "";
    
    // 根据不同的离开原因设置不同的颜色和状态
    if (StrContains(reason, "timed out", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07"); // 红色
        strcopy(statusMessage, sizeof(statusMessage), "\x05crashed");
    }
    else if (StrEqual(reason, "No Steam logon", false)) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07"); // 红色
        strcopy(statusMessage, sizeof(statusMessage), "\x05crashed");
    }
    else if (StrEqual(reason, "Disconnect by user.", false)) {
        strcopy(reasonColor, sizeof(reasonColor), "\x03"); // 绿色
        strcopy(statusMessage, sizeof(statusMessage), "\x03left");
    }
    else if (StrContains(reason, "Connection lost", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x09"); // 黄色
        strcopy(statusMessage, sizeof(statusMessage), "\x09lost connection");
    }
    else if (StrContains(reason, "kicked", false) != -1) {
        strcopy(reasonColor, sizeof(reasonColor), "\x07"); // 红色
        strcopy(statusMessage, sizeof(statusMessage), "\x07was kicked");
    }
    
    // 显示离开信息
    if (strlen(statusMessage) > 0) {
        PrintToChatAll("\x05%s \x03<%s> \x01disconnected (%s).\n\x05Reason: %s%s", 
                       playerName, steamId, statusMessage, reasonColor, reason);
    } else {
        PrintToChatAll("\x05%s \x03<%s> \x01disconnected.\n\x05Reason: %s%s", 
                       playerName, steamId, reasonColor, reason);
    }
    
    // 记录到日志
    LogMessage("[Connect Info] Player %s <%s> left the game: %s", playerName, steamId, reason);
    
    // 如果是崩溃情况，显示额外信息
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

// 保留这个函数作为备用，但主要逻辑已移到事件处理器中
public void OnClientDisconnect(int client) {
    // 清理存储的IP地址
    if (!IsFakeClient(client)) {
        g_ClientIPs[client][0] = '\0';
    }
}
