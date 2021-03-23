/*	[CS:GO] CowAntiCheat Plugin - Burn the cheaters!
 *
 *	Copyright (C) 2018 Eric Edson // ericedson.me // thefraggingcow@gmail.com
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1

#if defined _USE_DETOUR_FUNC_
#include <dhooks>
#endif	// _USE_DETOUR_FUNC_

#pragma newdecls required

public Plugin myinfo =
{
	name = "反作弊",
	author = Hoongdou,Cow,
	description = "",
	version = 1.0,
	url = ""
};

// bool sourcebans = false;

#define JUMP_HISTORY 100
#define MAX_TICK_DETECTION 100

int g_iCmdNum[MAXPLAYERS + 1];
int g_iAimbotCount[MAXPLAYERS + 1];
int g_iLastHitGroup[MAXPLAYERS + 1];
bool g_bAngleSet[MAXPLAYERS + 1];
float prev_angles[MAXPLAYERS + 1][3];
int g_iPerfectBhopCount[MAXPLAYERS + 1];
bool g_bThirdPersonEnabled[MAXPLAYERS + 1];
int g_iTicksOnGround[MAXPLAYERS + 1];
int g_iLastJumps[MAXPLAYERS + 1][JUMP_HISTORY];
int g_iLastJumpIndex[MAXPLAYERS + 1];
int g_iJumpsSent[MAXPLAYERS + 1][JUMP_HISTORY];
int g_iJumpsSentIndex[MAXPLAYERS + 1];
int g_iPrev_TicksOnGround[MAXPLAYERS + 1];
float prev_sidemove[MAXPLAYERS + 1];
int g_iPerfSidemove[MAXPLAYERS + 1];
int prev_buttons[MAXPLAYERS + 1];
bool g_bShootSpam[MAXPLAYERS + 1];
int g_iLastShotTick[MAXPLAYERS + 1];
bool g_bFirstShot[MAXPLAYERS + 1];
int g_iAutoShoot[MAXPLAYERS + 1];
int g_iTriggerBotCount[MAXPLAYERS + 1];
int g_iTicksOnPlayer[MAXPLAYERS + 1];
int g_iPrev_TicksOnPlayer[MAXPLAYERS + 1];
int g_iMacroCount[MAXPLAYERS + 1];
int g_iMacroDetectionCount[MAXPLAYERS + 1];
float g_fJumpStart[MAXPLAYERS + 1];
float g_fDefuseTime[MAXPLAYERS+1];
int g_iWallTrace[MAXPLAYERS + 1];
int g_iStrafeCount[MAXPLAYERS + 1];
bool turnRight[MAXPLAYERS + 1];
int g_iTickCount[MAXPLAYERS + 1];
int prev_mousedx[MAXPLAYERS + 1];
int g_iAHKStrafeDetection[MAXPLAYERS + 1];
int g_iMousedx_Value[MAXPLAYERS + 1];
int g_iMousedxCount[MAXPLAYERS + 1];
float g_fJumpPos[MAXPLAYERS + 1];
bool prev_OnGround[MAXPLAYERS + 1];
int g_iTickLeft[MAXPLAYERS + 1];
int g_iTickDetecton[MAXPLAYERS + 1];
float g_fTickDetectedTime[MAXPLAYERS + 1];
float g_fPrevLatency[MAXPLAYERS + 1];
int g_iMaxTick = 0;

float g_Sensitivity[MAXPLAYERS + 1];
float g_mYaw[MAXPLAYERS + 1];
Handle g_hTimerQueryTimeout[MAXPLAYERS + 1] = {null, ...};
int g_iQueryTimeout[MAXPLAYERS + 1] = {0, ...};

int g_iSendMoveCalled[MAXPLAYERS+1];
int g_iSendMoveRate[MAXPLAYERS+1];
float g_fSendMoveSecond[MAXPLAYERS+1];
bool g_bHasThirdChecked[MAXPLAYERS+1];
int g_iOffsetVomitTimer = -1;
float g_fVomitFadeTimer[MAXPLAYERS+1];
float g_fReleasedTimer[MAXPLAYERS+1];
float g_fDefibrillatorTimer[MAXPLAYERS+1];
float g_fGrenadeExplodeTimer[MAXPLAYERS+1];
float g_fGasCanTimer[MAXPLAYERS+1];
ArrayList g_aszClientSteamId;

/* Detection Cvars */
ConVar g_ConVar_AimbotEnable;
ConVar g_ConVar_SilentStrafeEnable;
ConVar g_ConVar_TriggerbotEnable;
ConVar g_ConVar_MacroEnable;
ConVar g_ConVar_AutoShootEnable;
ConVar g_ConVar_PerfectStrafeEnable;
ConVar g_ConVar_BacktrackFixEnable;
ConVar g_ConVar_AHKStrafeEnable;
ConVar g_ConVar_HourCheckEnable;
ConVar g_ConVar_HourCheckValue;
ConVar g_ConVar_ProfileCheckEnable;
ConVar g_ConVar_SpeedHackEnable;
ConVar g_ConVar_ThirdESPEnable;
ConVar g_ConVar_BlockSpecialIdle;
ConVar g_ConVar_BlockVomitIdle;
ConVar g_ConVar_BlockGrenadeIdle;
ConVar g_ConVar_VomitDuration;
ConVar g_ConVar_GrenadeDuration;
ConVar g_ConVar_FamilySharing;
ConVar g_ConVar_MatHack;
ConVar g_ConVar_BlockDefibIdle;
ConVar g_ConVar_BlockReleaseIdle;
ConVar g_ConVar_BlockReleaseDuration;
ConVar g_ConVar_BlockGasCanIdle;
ConVar g_ConVar_BlockGasCanDuration;
ConVar g_ConVar_QueryMaxTime;
ConVar g_ConVar_QueryMaxCount;

/* Detection Thresholds Cvars */
ConVar g_ConVar_AimbotBanThreshold;
ConVar g_ConVar_BhopBanThreshold;
ConVar g_ConVar_SilentStrafeBanThreshold;
ConVar g_ConVar_TriggerbotBanThreshold;
ConVar g_ConVar_TriggerbotLogThreshold;
ConVar g_ConVar_MacroLogThreshold;
ConVar g_ConVar_AutoShootLogThreshold;
ConVar g_ConVar_PerfectStrafeBanThreshold;
ConVar g_ConVar_PerfectStrafeLogThreshold;
ConVar g_ConVar_AHKStrafeLogThreshold;

/* Ban Times */
ConVar g_ConVar_AimbotBanTime;
ConVar g_ConVar_BhopBanTime;
ConVar g_ConVar_SilentStrafeBanTime;
ConVar g_ConVar_TriggerbotBanTime;
ConVar g_ConVar_PerfectStrafeBanTime;
ConVar g_ConVar_InstantDefuseBanTime;

public void OnPluginStart()
{
	g_ConVar_AimbotEnable = CreateConVar("cac_aimbot", "1", "是否开启自动瞄准检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_SilentStrafeEnable = CreateConVar("cac_silentstrafe", "1", "是否开启隐藏式自动传送检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_TriggerbotEnable = CreateConVar("cac_triggerbot", "1", "是否开启自动开枪检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_MacroEnable = CreateConVar("cac_macro", "1", "是否开启宏检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_AutoShootEnable = CreateConVar("cac_autoshoot", "1", "是否开启自动手枪连射检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_PerfectStrafeEnable = CreateConVar("cac_perfectstrafe", "1", "是否开启完美传送检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_BacktrackFixEnable = CreateConVar("cac_backtrack", "1", "是否开启屏蔽 Backtrack", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_AHKStrafeEnable = CreateConVar("cac_ahkstrafe", "1", "是否开启 AHK 传送检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_SpeedHackEnable = CreateConVar("cac_speedhack", "1", "是否开启加速检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_ThirdESPEnable = CreateConVar("cac_thirdesp", "1", "是否开启第三人称透视检测", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_FamilySharing = CreateConVar("cac_family_sharing", "1", "是否开启禁止家庭共享的玩家加入服务器", FCVAR_NONE, true, 0.0, true, 1.0);
	g_ConVar_MatHack = CreateConVar("cac_mathack", "1", "是否开启检查玩家的 mat_ 控制台变量", FCVAR_NONE, true, 0.0, true, 1.0);
	
	g_ConVar_AimbotBanThreshold = CreateConVar("cac_aimbot_ban_threshold", "5", "检测为自瞄需要的 tick 数量");
	g_ConVar_BhopBanThreshold = CreateConVar("cac_bhop_ban_threshold", "10", "检测为自动连跳需要的 tick 数量");
	g_ConVar_SilentStrafeBanThreshold = CreateConVar("cac_silentstrafe_ban_threshold", "10", "检测为隐藏式自动传送需要的 tick 数量");
	g_ConVar_TriggerbotBanThreshold = CreateConVar("cac_triggerbot_ban_threshold", "5", "检测为自动开枪需要的 tick 数量");
	g_ConVar_TriggerbotLogThreshold = CreateConVar("cac_triggerbot_log_threshold", "3", "检测自动开枪记录日志的 tick 数量");