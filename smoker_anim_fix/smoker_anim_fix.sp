#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

// 硬编码的序列ID和Activity ID（测试确定正确值）
#define SMOKER_TONGUE_SEQUENCE 67      // Smoker舌头攻击动画序列ID 测试67 68 均可以触发[65, 66, 67, 68, 69, 70, 71, 72]
#define SMOKER_TONGUE_ACTIVITY 1048    // Smoker舌头攻击Activity ID 目前只能1048[1047, 1048, 1049, 1050]
#define GESTURE_SLOT 6                 // 手势动画槽位

public Plugin myinfo = 
{
    name = "Smoker Animation Fix",
    author = "HoongDou",
    description = "Fixes AI Smoker tongue animation to match human players",
    version = "1.0",
    url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

public void OnPluginStart()
{
    HookEvent("ability_use", Event_AbilityUse);
    RegAdminCmd("sm_test_sequence", Command_TestSequence, ADMFLAG_ROOT, 
                "Test different animation sequences on AI Smoker");
    PrintToServer("[Smoker Fix] Plugin loaded with hardcoded sequence ID: %d", SMOKER_TONGUE_SEQUENCE);
}

public void Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int userid = event.GetInt("userid");
    int client = GetClientOfUserId(userid);
    
    if (client <= 0 || client > MaxClients || !IsClientInGame(client))
        return;
    
    // 检查是否为AI控制的玩家
    if (!IsFakeClient(client))
        return;
    
    // 检查玩家是否为感染者队伍
    if (GetClientTeam(client) != 3)
        return;
    
    // 检查玩家是否为Smoker (僵尸类别1)
    if (GetEntProp(client, Prop_Send, "m_zombieClass") != 1)
        return;
    
    // 检查是否为Smoker的舌头攻击
    char ability[64];
    event.GetString("ability", ability, sizeof(ability));
    int context = event.GetInt("context");
    
    if (StrEqual(ability, "ability_tongue") && context == 1)
    {
        ApplySmokerTongueAnimation(client);
    }
}

void ApplySmokerTongueAnimation(int client)
{
    // 获取当前模型并重新设置（刷新模型状态）
    char modelName[PLATFORM_MAX_PATH];
    GetClientModel(client, modelName, sizeof(modelName));
    SetEntityModel(client, modelName);
    
    // 获取网络属性偏移
    int gestureSequenceOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureSequence");
    int gestureActivityOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureActivity");
    int gestureStartTimeOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureStartTime");
    
    if (gestureSequenceOffset == -1 || gestureActivityOffset == -1 || gestureStartTimeOffset == -1)
    {
        PrintToServer("[Smoker Fix] Failed to find network properties");
        return;
    }
    
    // 计算偏移位置（手势槽位6）
    int slotOffset = GESTURE_SLOT * 4;
    
    // 设置手势动画序列
    SetEntData(client, gestureSequenceOffset + slotOffset, SMOKER_TONGUE_SEQUENCE, 4, true);
    
    // 设置手势活动
    SetEntData(client, gestureActivityOffset + slotOffset, SMOKER_TONGUE_ACTIVITY, 4, true);
    
    // 设置手势开始时间
    float currentTime = GetGameTime();
    SetEntDataFloat(client, gestureStartTimeOffset + slotOffset, currentTime, true);
    
    PrintToServer("[Smoker Fix] Applied tongue animation for client %d (Seq: %d, Act: %d, Time: %.2f)", 
                 client, SMOKER_TONGUE_SEQUENCE, SMOKER_TONGUE_ACTIVITY, currentTime);
}

// Debug：手动测试不同的序列ID
public Action Command_TestSequence(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_test_sequence <sequence_id> [activity_id]");
        return Plugin_Handled;
    }
    
    char arg1[32], arg2[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    int sequenceId = StringToInt(arg1);
    
    int activityId = SMOKER_TONGUE_ACTIVITY;
    if (args >= 2)
    {
        GetCmdArg(2, arg2, sizeof(arg2));
        activityId = StringToInt(arg2);
    }
    
    // 寻找AI Smoker进行测试
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 3 && 
            GetEntProp(i, Prop_Send, "m_zombieClass") == 1)
        {
            TestSequenceOnSmoker(i, sequenceId, activityId);
            ReplyToCommand(client, "Testing sequence %d (activity %d) on Smoker bot %d", 
                         sequenceId, activityId, i);
            return Plugin_Handled;
        }
    }
    
    ReplyToCommand(client, "No AI Smoker found to test on");
    return Plugin_Handled;
}

void TestSequenceOnSmoker(int client, int sequenceId, int activityId)
{
    char modelName[PLATFORM_MAX_PATH];
    GetClientModel(client, modelName, sizeof(modelName));
    SetEntityModel(client, modelName);
    
    int gestureSequenceOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureSequence");
    int gestureActivityOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureActivity");
    int gestureStartTimeOffset = FindSendPropInfo("CTerrorPlayer", "m_NetGestureStartTime");
    
    if (gestureSequenceOffset != -1 && gestureActivityOffset != -1 && gestureStartTimeOffset != -1)
    {
        int slotOffset = GESTURE_SLOT * 4;
        
        SetEntData(client, gestureSequenceOffset + slotOffset, sequenceId, 4, true);
        SetEntData(client, gestureActivityOffset + slotOffset, activityId, 4, true);
        
        float currentTime = GetGameTime();
        SetEntDataFloat(client, gestureStartTimeOffset + slotOffset, currentTime, true);
        
        PrintToServer("[Test] Applied sequence %d, activity %d to client %d", 
                     sequenceId, activityId, client);
    }
}

public void OnPluginEnd()
{
    PrintToServer("[Smoker Fix] Plugin unloaded");
}