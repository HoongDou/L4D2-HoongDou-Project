#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <ripext>

#define DEBUG
#define CONFIG_FILE "cfg/sourcemod/ip_data_api.cfg" // 配置文件路径

char g_ClientIPs[MAXPLAYERS+1][36]; // 用于存储每位客户端的 IP 地址
ConVar g_hAPIKey; // 用于存储 API 密钥配置的 ConVar

public Plugin myinfo = {
    name = "Connect info",
    author = "HoongDou",
    description = "Print SteamID and IP in chat via HTTP requests with REST in Pawn",
    version = "1.8", 
    url = ""
};

// 插件初始化
public void OnPluginStart() {
    AutoExecConfig(true, "ip_data_api");
    g_hAPIKey = CreateConVar("sm_ipdata_apikey", "", "API key for ipdata.co", FCVAR_PROTECTED | FCVAR_NOTIFY);
    
    // 绑定变量变动时的回调函数
    HookConVarChange(g_hAPIKey, OnAPIKeyChanged);
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
    
    // 清理 JSON 对象
    delete jsonObject;
    
    char userSteamID[32];
    GetClientAuthId(client, AuthId_Steam2, userSteamID, sizeof(userSteamID)); // 获取客户端的 Steam ID

    // 向所有人广播客户端的连接信息，包括 Steam ID、国家码、城市名称和 IP 地址
    PrintToChatAll("\x05%N \x03<%s>\x01 connected \nFrom\x05[\x03%s \x01 %s\x05]\x04 %s", client, userSteamID, countryCode, city, g_ClientIPs[client]);
}


public void OnAPIKeyChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    LogMessage("API key changed from '%s' to '%s'", oldValue, newValue);
}


public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
    {
        PrintToChatAll("\x05%N \x01disconnected.", client);
    }
}
