//+------------------------------------------------------------------+
//|                                     Prime_Quantum_AI.mq5         |
//|                                     Version 3.21 (Single-File)   |
//+------------------------------------------------------------------+
//  ╔══════════════════════════════════════════════════════════════════╗
//  ║      PRIME QUANTUM AI v3.20 — Premium AI-Powered Trading       ║
//  ║              SINGLE-FILE BUILD (engine merged in)              ║
//  ║                                                                ║
//  ║  • Multi-provider AI chart analysis (Claude, GPT, Gemini...)   ║
//  ║  • TF input fully controls pre-filter + screenshots            ║
//  ║  • Adaptive screenshot stack auto-selected from entry TF       ║
//  ║  • AI prompt tells model the actual TF names it is viewing     ║
//  ║  • Prop Firm & Standard broker modes                           ║
//  ║  • News, Time (GMT/Broker), Day, and Spread filters            ║
//  ║  • Optional Martingale with lot step control                   ║
//  ║  • AI-guided or Fixed SL/TP (pips or points)                   ║
//  ║  • Trailing stop, partial close, emergency controls            ║
//  ║  • Fully customizable professional panel                       ║
//  ║  • Indicator parameters now USER-EDITABLE in inputs            ║
//  ║                                                                ║
//  ║  SETUP: Tools > Options > Expert Advisors > Allow WebRequest   ║
//  ║  Add:  https://api.anthropic.com                               ║
//  ║        https://api.openai.com                                  ║
//  ║        https://generativelanguage.googleapis.com               ║
//  ║        https://api.deepseek.com                                ║
//  ║        https://api.x.ai                                        ║
//  ╚══════════════════════════════════════════════════════════════════╝
//+------------------------------------------------------------------+

#property copyright   "Prime Quantum AI"
#property link        ""
#property version     "3.21"
#property description "Prime Quantum AI v3.21 — Adaptive TF AI Trading (Single-File)"
#property description "Two trading modes: Indicators-Only (no API needed) or AI Hybrid (API+Indicators)"
#property description "Dual Account Mode: Standard Broker (Money Filter) + Prop Firm Risk Management"
#property description "Supports: Anthropic Claude, OpenAI GPT, Google Gemini, DeepSeek, xAI Grok"
#property strict

#include <Trade\Trade.mqh>

//=============================================================================
//  ENUMS
//=============================================================================
enum ENUM_AI_PROVIDER
{
   PROVIDER_UNKNOWN   = 0,  // Unknown
   PROVIDER_ANTHROPIC = 1,  // Anthropic (Claude)
   PROVIDER_OPENAI    = 2,  // OpenAI (GPT)
   PROVIDER_GOOGLE    = 3,  // Google (Gemini)
   PROVIDER_DEEPSEEK  = 4,  // DeepSeek
   PROVIDER_XAI       = 5   // xAI (Grok)
};

enum ENUM_ACCOUNT_TYPE
{
   ACCOUNT_STANDARD   = 0, // Standard Broker
   ACCOUNT_PROP_FIRM  = 1, // Prop Firm / Challenge
   ACCOUNT_FUNDED     = 2  // Funded Account
};

enum ENUM_RISK_MODE
{
   RISK_FIXED_LOT          = 0, // Fixed Lot Size
   RISK_PERCENT_BALANCE    = 1, // % of Balance
   RISK_PERCENT_EQUITY     = 2, // % of Equity
   RISK_FIXED_MONEY        = 3, // Fixed $ at Risk
   RISK_PERCENT_FREE_MARGIN= 4  // % of Free Margin
};

enum ENUM_SLTP_MODE
{
   SLTP_AI_DECIDES     = 0, // AI Determines SL/TP
   SLTP_FIXED_PIPS     = 1, // Fixed (Pips)
   SLTP_FIXED_POINTS   = 2, // Fixed (Points)
   SLTP_AI_SL_RR       = 3  // AI SL + Risk:Reward
};

enum ENUM_TRAIL_MODE
{
   TRAIL_FIXED          = 0, // Fixed Distance
   TRAIL_ATR            = 1, // ATR-Based
   TRAIL_BREAKEVEN_PLUS = 2  // Breakeven + Pips
};

enum ENUM_AI_DIRECTION
{
   AI_DIR_NONE = 0,
   AI_DIR_BUY  = 1,
   AI_DIR_SELL = 2
};

enum ENUM_PREFILTER_SIGNAL
{
   SIGNAL_NONE    = 0,
   SIGNAL_BULLISH = 1,
   SIGNAL_BEARISH = 2
};

enum ENUM_TIME_MODE
{
   TIME_BROKER      = 0,  // Broker Server Time
   TIME_GMT_OFFSET  = 1   // GMT + Offset
};

enum ENUM_TRADING_MODE
{
   MODE_INDICATORS_ONLY = 0,  // Indicators Only (no API required) — Market-safe
   MODE_AI_HYBRID       = 1   // AI Hybrid (Indicators + AI Vision confirmation)
};

enum ENUM_PROP_RISK_UNIT
{
   PROP_UNIT_PERCENT = 0,   // Percent of Initial Balance (%)
   PROP_UNIT_MONEY   = 1    // Fixed Amount (Account Currency $)
};

//=============================================================================
//  STRUCTS
//=============================================================================
struct AIAnalysisResult
{
   ENUM_AI_DIRECTION direction;
   int               confidence;
   double            slPrice;
   double            tpPrice;
   string            slReason;
   string            tpReason;
   string            reason;
   bool              isValid;

   void Reset()
   {
      direction  = AI_DIR_NONE;
      confidence = 0;
      slPrice    = 0;
      tpPrice    = 0;
      slReason   = "";
      tpReason   = "";
      reason     = "";
      isValid    = false;
   }
};

struct LastTradeInfo
{
   bool   hasHistory;
   bool   wasLoss;
   bool   wasBuy;
   double lastLotSize;
   int    consecutiveLosses;
   int    consecutiveWins;
   double lastProfit;
};

struct SessionStats
{
   int    totalTrades;
   int    wins;
   int    losses;
   double totalProfit;
   double totalLoss;
   int    currentConsecWins;
   int    currentConsecLosses;
   double dailyPL;
};

struct DrawdownTracker
{
   double startingDayBalance;
   double initialBalance;
   double highWaterMark;
   double dailyPL;
   double totalDrawdown;
   bool   dailyLimitHit;
   bool   totalLimitHit;
   bool   profitTargetHit;
   datetime lastDayReset;
};

struct PreFilterState
{
   double adxValue;
   bool   diPlusAbove;
   bool   alligatorBull;
   bool   alligatorBear;
   ENUM_PREFILTER_SIGNAL signal;
};

struct PanelConfig
{
   int    panelWidth;
   int    fontSizeData;
   int    fontSizeHeader;
   int    fontSizeTitle;
   string fontData;
   string fontHeader;

   color  clrBackground;
   color  clrHeader;
   color  clrSectionHdr;
   color  clrAccent;
   color  clrBullish;
   color  clrBearish;
   color  clrWarning;
   color  clrTextPrimary;
   color  clrTextSecondary;
   color  clrTextMuted;
   color  clrBorder;
   color  clrProgressBg;

   color  clrInactiveBg;
   color  clrInactiveHdr;
   color  clrInactiveBorder;
   color  clrInactiveText;

   string timeModeLabel;
};

struct PanelData
{
   double balance;
   double equity;
   double freeMargin;
   double dailyPL;
   double drawdownPct;

   double bid;
   double ask;
   int    spreadPoints;

   ENUM_AI_PROVIDER provider;
   string           modelName;
   int              apiCallsToday;
   string           aiStatus;
   string           lastDecision;
   int              lastConfidence;
   string           lastReason;

   bool   hasPosition;
   string positionType;
   double positionLots;
   double positionSL;
   double positionTP;
   double positionPL;
   int    tradesToday;
   int    winsToday;
   int    lossesToday;

   string riskModeName;
   double nextLotSize;
   int    martingaleLevel;

   bool   showPropFirm;
   double dailyDDPct;
   double dailyDDLimit;
   double totalDDPct;
   double totalDDLimit;

   datetime lastUpdate;
   bool     connected;

   string nextNewsEvent;
   int    newsMinutesAway;

   bool   eaActive;
   string blockReason;
   int    nextScanSec;

   string currentTimeStr;

   string tfEntryName;
   string tfMidName;
   string tfHighName;
};

//=============================================================================
//  CONSTANTS
//=============================================================================
#define AIV_VERSION           "3.20"
#define AIV_EA_NAME           "Prime Quantum AI"

#define PANEL_ROW_HEIGHT       16
#define PANEL_SECTION_GAP      4
#define PANEL_PADDING          10
#define PANEL_FONT_SIZE_BRAND  7

#define URL_ANTHROPIC          "https://api.anthropic.com/v1/messages"
#define URL_OPENAI             "https://api.openai.com/v1/chat/completions"
#define URL_GOOGLE             "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
#define URL_DEEPSEEK           "https://api.deepseek.com/v1/chat/completions"
#define URL_XAI                "https://api.x.ai/v1/chat/completions"

#define MODEL_ANTHROPIC        "claude-sonnet-4-20250514"
#define MODEL_OPENAI           "gpt-4o"
#define MODEL_GOOGLE           "gemini-2.0-flash"
#define MODEL_DEEPSEEK         "deepseek-chat"
#define MODEL_XAI              "grok-2-vision"

#define COST_PER_CALL          0.02

//=============================================================================
//  INPUT PARAMETERS
//=============================================================================
input group "═══════════════ TRADING MODE ═══════════════"
input ENUM_TRADING_MODE InpTradingMode = MODE_INDICATORS_ONLY; // Trading Mode (Indicators only or AI Hybrid)

input group "═══════════════ TRADING STYLE ═══════════════"
input ENUM_TIMEFRAMES TF = PERIOD_M15; // Scalping: M1/M5/M15 | Day trade: H1/H4 | Swing: D1

input group "═══════════════ EA Settings ═══════════════"
input int    InpMagicNumber    = 100001;           // Magic Number
input string InpTradeComment   = "Prime Quantum AI";   // Trade Comment

input group "═══════════════ AI API Settings  (only used when Trading Mode = AI Hybrid) ═══════════════"
input string InpAPIKey           = "";             // API Key (paste your key — required for AI Hybrid mode)
input string InpProviderOverride = "auto";         // Provider (auto / anthropic / openai / google / deepseek / xai)
input int    InpMinConfidence    = 70;             // Minimum AI Confidence (0-100)
input int    InpAPITimeoutSec    = 30;             // API Timeout (seconds)
input int    InpScanIntervalSec  = 120;            // Scan Interval (seconds between AI calls)

input group "═══════════════ Chart Capture ═══════════════"
input int    InpChartWidth  = 1920;                // Screenshot Width (px)
input int    InpChartHeight = 1080;                // Screenshot Height (px)
input int    InpChartBars   = 200;                 // Bars Visible on Chart

//─── Pre-Filter Indicator Inputs (NEW: now user-editable) ────────────────────
input group "═══════════════ Pre-Filter: ADX ═══════════════"
input int    InpADXPeriod      = 14;               // ADX Period
input double InpADXMinLevel    = 25.0;             // ADX Minimum Trend Strength

input group "═══════════════ Pre-Filter: Alligator ═══════════════"
input int    InpJawPeriod      = 13;               // Jaw Period (Blue line)
input int    InpJawShift       = 8;                // Jaw Shift
input int    InpTeethPeriod    = 8;                // Teeth Period (Red line)
input int    InpTeethShift     = 5;                // Teeth Shift
input int    InpLipsPeriod     = 5;                // Lips Period (Green line)
input int    InpLipsShift      = 3;                // Lips Shift

input group "═══════════════ Trailing Stop Indicator ═══════════════"
input int    InpATRTrailPeriod = 14;               // ATR Period (for ATR Trailing Stop)

//=============================================================================
//  ACCOUNT MODE
//=============================================================================
input group "═══════════════ Account Mode ═══════════════"
input ENUM_ACCOUNT_TYPE InpAccountType       = ACCOUNT_STANDARD;  // Account Type (Standard Broker / Prop Firm / Funded)

input group "═══════════════ Money Filter  (Standard Broker) ═══════════════"
input bool   InpUseMoneyFilter               = true;              // Enable Money Filter
input double InpEquityProfitTarget           = 5000.0;            // Profit Target — Stop when Equity >= this ($)
input double InpEquityLossLimit              = 2500.0;            // Loss Limit   — Stop when Equity <= this ($)

input group "═══════════════ Prop Firm Risk Management  (Prop Firm / Funded) ═══════════════"
input double              InpPropInitBalance         = 0;                 // Challenge Initial Balance (0 = auto-detect)
input ENUM_PROP_RISK_UNIT InpPropRiskUnit            = PROP_UNIT_PERCENT; // Risk Unit — use % or $ for values below
input double              InpPropDailyProfitTarget   = 2.0;               // Daily Profit Target      (% or $, 0 = disabled)
input double              InpPropDailyLossLimit      = 5.0;               // Daily Loss Limit / Max Daily Drawdown (% or $)
input double              InpPropMaxTotalDrawdown    = 10.0;              // Max Total Drawdown       (% or $)
input bool                InpPropUseTrailingDrawdown = false;             // Enable Trailing Drawdown (high-water-mark based)
input double              InpPropChallengeTarget     = 0;                 // Overall Challenge Profit Target (% or $, 0 = disabled)

input group "═══════════════ Risk Management ═══════════════"
input ENUM_RISK_MODE InpRiskMode   = RISK_FIXED_LOT;  // Risk Mode
input double InpFixedLot           = 0.01;             // Fixed Lot Size
input double InpRiskPercent        = 1.0;              // Risk Percent
input double InpRiskMoney          = 50.0;             // Risk Amount ($)
input double InpMaxLot             = 5.0;              // Maximum Lot Cap
input double InpMinLot             = 0.01;             // Minimum Lot Size

input group "═══════════════ Martingale ═══════════════"
input bool   InpUseMartingale            = false;  // Enable Martingale
input double InpMartingaleMultiplier     = 2.0;    // Lot Multiplier After Loss
input double InpMartingaleLotStep        = 0;      // Lot Step After Loss (0=use multiplier)
input int    InpMartingaleMaxLevel       = 5;      // Max Martingale Level
input bool   InpMartingaleResetDaily     = true;   // Reset Martingale Daily

input group "═══════════════ SL / TP Settings ═══════════════"
input ENUM_SLTP_MODE InpSLTPMode   = SLTP_AI_DECIDES;  // SL/TP Mode
input double InpFixedSL_Pips       = 30.0;              // Fixed SL (pips)
input double InpFixedTP_Pips       = 60.0;              // Fixed TP (pips)
input int    InpFixedSL_Points     = 300;               // Fixed SL (points)
input int    InpFixedTP_Points     = 600;               // Fixed TP (points)
input double InpRiskReward         = 2.0;               // Risk:Reward Ratio
input double InpMinSL_Pips         = 10.0;              // Minimum SL (pips)
input double InpMaxSL_Pips         = 100.0;             // Maximum SL (pips)
input double InpPipMultiplier      = 10.0;              // Points per Pip

input group "═══════════════ News Filter ═══════════════"
input bool   InpUseNewsFilter      = true;         // Enable News Filter
input int    InpNewsMinutesBefore  = 30;           // Pause Before News (minutes)
input int    InpNewsMinutesAfter   = 30;           // Resume After News (minutes)
input bool   InpNewsHighImpactOnly = true;         // High Impact Only

input group "═══════════════ Trading Hours ═══════════════"
input ENUM_TIME_MODE InpTimeMode       = TIME_BROKER;   // Time Reference
input int            InpGMTOffsetHours = 0;              // GMT Offset Hours (e.g. 2 = GMT+2)
input int            InpGMTOffsetMins  = 0;              // GMT Offset Minutes (0 or 30)
input string         InpTradingStartTime  = "02:00";     // Start Time (HH:MM)
input string         InpTradingEndTime    = "22:00";     // End Time (HH:MM)

input group "═══════════════ Trading Days ═══════════════"
input bool   InpTradeMonday       = true;          // Monday
input bool   InpTradeTuesday      = true;          // Tuesday
input bool   InpTradeWednesday    = true;          // Wednesday
input bool   InpTradeThursday     = true;          // Thursday
input bool   InpTradeFriday       = true;          // Friday
input bool   InpCloseFriday       = false;         // Close All Friday at Time
input string InpFridayCloseTime   = "20:00";       // Friday Close Time

input group "═══════════════ Spread Filter ═══════════════"
input int    InpMaxSpread = 30;                    // Max Spread (points, 0=off)

input group "═══════════════ Trailing Stop ═══════════════"
input bool            InpUseTrailingStop    = false;        // Enable Trailing Stop
input ENUM_TRAIL_MODE InpTrailMode          = TRAIL_FIXED;  // Trail Mode
input double          InpTrailDistance      = 20.0;         // Trail Distance (pips)
input double          InpBreakevenPlus      = 5.0;          // Breakeven + Pips
input double          InpATRTrailMultiplier = 1.5;          // ATR Multiplier

input group "═══════════════ Partial Close ═══════════════"
input bool   InpUsePartialClose    = false;        // Enable Partial Close
input double InpPartialClose1_Pct  = 50.0;         // Close % at TP1
input double InpPartialClose1_RR   = 1.0;          // TP1 at R:R
input double InpPartialClose2_Pct  = 30.0;         // Close % at TP2
input double InpPartialClose2_RR   = 2.0;          // TP2 at R:R

input group "═══════════════ Alerts ═══════════════"
input bool   InpAlertOnTrade     = true;           // Alert on Trade
input bool   InpPushNotification = true;           // Push Notification
input bool   InpEmailAlert       = false;          // Email Alert

input group "═══════════════ Panel Display ═══════════════"
input bool             InpShowPanel        = true;               // Show Panel
input ENUM_BASE_CORNER InpPanelCorner      = CORNER_LEFT_UPPER;  // Panel Corner
input int              InpPanelX           = 10;                 // Panel X Position
input int              InpPanelY           = 30;                 // Panel Y Position

input group "═══════════════ Panel Appearance ═══════════════"
input int              InpPanelWidth       = 320;                // Panel Width (px)
input int              InpFontSizeData     = 8;                  // Data Font Size
input int              InpFontSizeHeader   = 9;                  // Section Header Font Size
input int              InpFontSizeTitle    = 11;                 // Title Font Size
input string           InpFontData         = "Consolas";         // Data Font Name
input string           InpFontHeader       = "Segoe UI Semibold";// Header Font Name

input group "═══════════════ Panel Colors ═══════════════"
input color  InpClrBackground     = C'15,17,26';     // Background Color
input color  InpClrHeader         = C'10,12,22';     // Header Color
input color  InpClrSectionHeader  = C'20,24,38';     // Section Header Color
input color  InpClrAccent         = C'218,165,32';   // Accent Color (gold)
input color  InpClrBullish        = C'46,204,113';   // Bullish / Positive Color
input color  InpClrBearish        = C'231,76,60';    // Bearish / Negative Color
input color  InpClrWarning        = C'241,196,15';   // Warning Color
input color  InpClrTextPrimary    = C'224,224,224';  // Primary Text Color
input color  InpClrTextSecondary  = C'130,140,165';  // Label Text Color
input color  InpClrTextMuted      = C'70,78,100';    // Muted Text Color
input color  InpClrBorder         = C'35,42,65';     // Border Color

input group "═══════════════ Emergency ═══════════════"
input string InpEmergencyKey = "X";                // Emergency Close Key

//=============================================================================
//  HELPER: TF Name String
//=============================================================================
string TFName(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "CURRENT";
   }
}

//=============================================================================
//  HELPER: Adaptive Screenshot TF Selection
//=============================================================================
void GetScreenshotTimeframes(ENUM_TIMEFRAMES entryTF,
                              ENUM_TIMEFRAMES &tfEntry,
                              ENUM_TIMEFRAMES &tfMid,
                              ENUM_TIMEFRAMES &tfHigh)
{
   switch(entryTF)
   {
      case PERIOD_M1:
         tfEntry = PERIOD_M1; tfMid = PERIOD_M15; tfHigh = PERIOD_H1; break;
      case PERIOD_M2: case PERIOD_M3: case PERIOD_M4: case PERIOD_M5:
         tfEntry = entryTF; tfMid = PERIOD_M30; tfHigh = PERIOD_H1; break;
      case PERIOD_M6: case PERIOD_M10: case PERIOD_M12: case PERIOD_M15:
         tfEntry = entryTF; tfMid = PERIOD_H1; tfHigh = PERIOD_H4; break;
      case PERIOD_M20: case PERIOD_M30:
         tfEntry = entryTF; tfMid = PERIOD_H4; tfHigh = PERIOD_D1; break;
      case PERIOD_H1: case PERIOD_H2: case PERIOD_H3:
         tfEntry = entryTF; tfMid = PERIOD_H4; tfHigh = PERIOD_D1; break;
      case PERIOD_H4: case PERIOD_H6: case PERIOD_H8: case PERIOD_H12:
         tfEntry = entryTF; tfMid = PERIOD_D1; tfHigh = PERIOD_W1; break;
      case PERIOD_D1:
         tfEntry = PERIOD_D1; tfMid = PERIOD_W1; tfHigh = PERIOD_MN1; break;
      case PERIOD_W1: case PERIOD_MN1:
         tfEntry = entryTF; tfMid = PERIOD_W1; tfHigh = PERIOD_MN1; break;
      default:
         tfEntry = PERIOD_M15; tfMid = PERIOD_H1; tfHigh = PERIOD_H4; break;
   }
}

//╔═══════════════════════════════════════════════════════════════════╗
//║                       CLASS: CFilters                           ║
//╚═══════════════════════════════════════════════════════════════════╝
class CFilters
{
private:
   int             m_handleADX;
   int             m_handleAlligator;
   string          m_symbol;
   int             m_magic;
   ENUM_TIMEFRAMES m_tf;
   double          m_adxMinLevel;
   string          m_nextNewsName;
   datetime        m_nextNewsTime;
   int             m_newsMinutesAway;

   void ParseTimeString(const string timeStr, int &hour, int &minute)
   {
      hour = 0; minute = 0;
      int colonPos = StringFind(timeStr, ":");
      if(colonPos > 0)
      {
         hour   = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
         minute = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1));
      }
      else hour = (int)StringToInteger(timeStr);
   }

   double GetBuffer(int handle, int bufferIndex, int bar)
   {
      double arr[];
      ArraySetAsSeries(arr, true);
      if(CopyBuffer(handle, bufferIndex, 0, bar + 2, arr) < bar + 2)
         return EMPTY_VALUE;
      return arr[bar];
   }

   int GetCurrentMinutes(ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      if(mode == TIME_BROKER)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         return dt.hour * 60 + dt.min;
      }
      datetime gmtTime = TimeGMT();
      int totalOffsetSec = gmtOffsetH * 3600 + gmtOffsetM * 60;
      datetime userTime = gmtTime + totalOffsetSec;
      MqlDateTime dt;
      TimeToStruct(userTime, dt);
      return dt.hour * 60 + dt.min;
   }

   int GetCurrentDayOfWeek(ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      if(mode == TIME_BROKER)
      {
         MqlDateTime dt;
         TimeToStruct(TimeCurrent(), dt);
         return dt.day_of_week;
      }
      datetime gmtTime = TimeGMT();
      int totalOffsetSec = gmtOffsetH * 3600 + gmtOffsetM * 60;
      datetime userTime = gmtTime + totalOffsetSec;
      MqlDateTime dt;
      TimeToStruct(userTime, dt);
      return dt.day_of_week;
   }

public:
   CFilters() : m_handleADX(INVALID_HANDLE), m_handleAlligator(INVALID_HANDLE),
                m_tf(PERIOD_M15), m_adxMinLevel(25.0),
                m_nextNewsName(""), m_nextNewsTime(0), m_newsMinutesAway(-1) {}

   bool Init(const string symbol, int magic, ENUM_TIMEFRAMES tf,
             int adxPeriod, double adxMinLevel,
             int jawP, int jawS, int teethP, int teethS, int lipsP, int lipsS)
   {
      m_symbol = symbol;
      m_magic  = magic;
      m_tf     = tf;
      m_adxMinLevel = adxMinLevel;

      m_handleADX = iADX(m_symbol, m_tf, adxPeriod);
      if(m_handleADX == INVALID_HANDLE)
      {
         PrintFormat("[Filters] FAILED ADX handle on %s | Err=%d", TFName(m_tf), GetLastError());
         return false;
      }

      m_handleAlligator = iAlligator(
         m_symbol, m_tf,
         jawP,   jawS,
         teethP, teethS,
         lipsP,  lipsS,
         MODE_SMMA, PRICE_MEDIAN
      );
      if(m_handleAlligator == INVALID_HANDLE)
      {
         PrintFormat("[Filters] FAILED Alligator handle on %s | Err=%d", TFName(m_tf), GetLastError());
         return false;
      }

      PrintFormat("[Filters] Indicators initialized on %s | ADX(%d, min=%.1f) | Alligator(%d/%d, %d/%d, %d/%d)",
         TFName(m_tf), adxPeriod, adxMinLevel, jawP, jawS, teethP, teethS, lipsP, lipsS);
      return true;
   }

   void Deinit()
   {
      if(m_handleADX != INVALID_HANDLE)       { IndicatorRelease(m_handleADX);       m_handleADX = INVALID_HANDLE; }
      if(m_handleAlligator != INVALID_HANDLE) { IndicatorRelease(m_handleAlligator); m_handleAlligator = INVALID_HANDLE; }
   }

   string GetCurrentTimeString(ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      if(mode == TIME_BROKER)
         return TimeToString(TimeCurrent(), TIME_SECONDS);
      datetime gmtTime = TimeGMT();
      int totalOffsetSec = gmtOffsetH * 3600 + gmtOffsetM * 60;
      datetime userTime = gmtTime + totalOffsetSec;
      return TimeToString(userTime, TIME_SECONDS);
   }

   PreFilterState EvaluatePreFilters()
   {
      PreFilterState state;
      state.adxValue      = 0;
      state.diPlusAbove   = false;
      state.alligatorBull = false;
      state.alligatorBear = false;
      state.signal        = SIGNAL_NONE;

      double adx     = GetBuffer(m_handleADX, 0, 1);
      double diPlus  = GetBuffer(m_handleADX, 1, 1);
      double diMinus = GetBuffer(m_handleADX, 2, 1);
      double jaw     = GetBuffer(m_handleAlligator, 0, 1);
      double teeth   = GetBuffer(m_handleAlligator, 1, 1);
      double lips    = GetBuffer(m_handleAlligator, 2, 1);

      if(adx == EMPTY_VALUE || diPlus == EMPTY_VALUE || diMinus == EMPTY_VALUE ||
         jaw == EMPTY_VALUE || teeth == EMPTY_VALUE  || lips == EMPTY_VALUE)
         return state;

      state.adxValue    = adx;
      state.diPlusAbove = (diPlus > diMinus);
      state.alligatorBull = (lips > teeth && teeth > jaw);
      state.alligatorBear = (lips < teeth && teeth < jaw);

      if(adx > m_adxMinLevel)
      {
         if(state.diPlusAbove && state.alligatorBull)
            state.signal = SIGNAL_BULLISH;
         else if(!state.diPlusAbove && state.alligatorBear)
            state.signal = SIGNAL_BEARISH;
      }
      return state;
   }

   bool IsNewsBlocking(bool useNews, int minBefore, int minAfter, bool highOnly)
   {
      if(!useNews) return false;

      m_nextNewsName    = "";
      m_nextNewsTime    = 0;
      m_newsMinutesAway = -1;

      MqlCalendarValue values[];
      datetime startTime = iTime(m_symbol, PERIOD_D1, 0);
      datetime endTime   = startTime + PeriodSeconds(PERIOD_D1);

      if(!CalendarValueHistory(values, startTime, endTime, NULL, NULL))
         return false;

      datetime now = TimeCurrent();
      datetime closestFuture = 0;

      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent   calEvent;
         MqlCalendarCountry country;
         CalendarEventById(values[i].event_id, calEvent);
         CalendarCountryById(calEvent.country_id, country);

         if(StringFind(m_symbol, country.currency) < 0) continue;

         if(highOnly)
         {
            if(calEvent.importance != CALENDAR_IMPORTANCE_HIGH) continue;
         }
         else
         {
            if(calEvent.importance == CALENDAR_IMPORTANCE_NONE ||
               calEvent.importance == CALENDAR_IMPORTANCE_LOW) continue;
         }

         datetime eventTime = values[i].time;

         if(eventTime > now && (closestFuture == 0 || eventTime < closestFuture))
         {
            closestFuture     = eventTime;
            m_nextNewsName    = calEvent.name;
            m_nextNewsTime    = eventTime;
            m_newsMinutesAway = (int)((eventTime - now) / 60);
         }

         datetime blockStart = eventTime - minBefore * 60;
         datetime blockEnd   = eventTime + minAfter  * 60;

         if(now >= blockStart && now < blockEnd)
         {
            m_nextNewsName    = calEvent.name;
            m_nextNewsTime    = eventTime;
            m_newsMinutesAway = (int)((eventTime - now) / 60);
            return true;
         }
      }
      return false;
   }

   string   GetNextNewsName()    const { return m_nextNewsName; }
   int      GetNewsMinutesAway() const { return m_newsMinutesAway; }
   ENUM_TIMEFRAMES GetTF()       const { return m_tf; }

   bool IsInTradingTime(const string startStr, const string endStr,
                        ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      int startH=0, startM=0, endH=0, endM=0;
      ParseTimeString(startStr, startH, startM);
      ParseTimeString(endStr,   endH,   endM);
      int now = GetCurrentMinutes(mode, gmtOffsetH, gmtOffsetM);
      int st  = startH * 60 + startM;
      int en  = endH   * 60 + endM;
      if(st < en) return (now >= st && now < en);
      else        return (now >= st || now < en);
   }

   bool IsTradingDay(bool mon, bool tue, bool wed, bool thu, bool fri,
                     ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      int dow = GetCurrentDayOfWeek(mode, gmtOffsetH, gmtOffsetM);
      switch(dow)
      {
         case 0: return false;
         case 1: return mon;
         case 2: return tue;
         case 3: return wed;
         case 4: return thu;
         case 5: return fri;
         case 6: return false;
      }
      return false;
   }

   bool IsFridayCloseTime(bool enabled, const string closeTimeStr,
                          ENUM_TIME_MODE mode, int gmtOffsetH, int gmtOffsetM)
   {
      if(!enabled) return false;
      int dow = GetCurrentDayOfWeek(mode, gmtOffsetH, gmtOffsetM);
      if(dow != 5) return false;
      int ch=0, cm=0;
      ParseTimeString(closeTimeStr, ch, cm);
      int now = GetCurrentMinutes(mode, gmtOffsetH, gmtOffsetM);
      return (now >= ch * 60 + cm);
   }

   bool IsSpreadOK(int maxSpread)
   {
      if(maxSpread <= 0) return true;
      return ((int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) <= maxSpread);
   }

   int GetCurrentSpread()
   {
      return (int)SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }
};

//╔═══════════════════════════════════════════════════════════════════╗
//║                     CLASS: CRiskManager                         ║
//╚═══════════════════════════════════════════════════════════════════╝
class CRiskManager
{
private:
   string           m_symbol;
   int              m_magic;
   int              m_martingaleLevel;
   double           m_lastBaseLot;
   DrawdownTracker  m_dd;
   SessionStats     m_stats;

   double NormalizeLot(double lots)
   {
      double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      lots = MathRound(lots / lotStep) * lotStep;
      int digits = 2;
      if(lotStep >= 1.0)       digits = 0;
      else if(lotStep >= 0.1)  digits = 1;
      else if(lotStep >= 0.01) digits = 2;
      else                     digits = 3;
      lots = NormalizeDouble(lots, digits);
      return lots;
   }

public:
   CRiskManager() : m_martingaleLevel(0), m_lastBaseLot(0) {}

   void Init(const string symbol, int magic, double initBalance)
   {
      m_symbol = symbol;
      m_magic  = magic;
      m_martingaleLevel = 0;
      m_lastBaseLot     = 0;

      m_dd.initialBalance     = initBalance > 0 ? initBalance : AccountInfoDouble(ACCOUNT_BALANCE);
      m_dd.startingDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dd.highWaterMark      = AccountInfoDouble(ACCOUNT_EQUITY);
      m_dd.dailyPL            = 0;
      m_dd.totalDrawdown      = 0;
      m_dd.dailyLimitHit      = false;
      m_dd.totalLimitHit      = false;
      m_dd.profitTargetHit    = false;
      m_dd.lastDayReset       = iTime(m_symbol, PERIOD_D1, 0);

      ZeroMemory(m_stats);
      RecalcSessionStats();
   }

   double CalculateLotSize(double slDistPts,
                           ENUM_RISK_MODE riskMode, double fixedLot, double riskPct,
                           double riskMoney, double minLot, double maxLotCap,
                           bool useMartingale, double martMulti, int martMaxLvl,
                           double lotStep,
                           ENUM_ACCOUNT_TYPE accType,
                           double maxDailyDD)
   {
      double baseLot = CalcLotFromRisk(slDistPts, riskMode, fixedLot, riskPct, riskMoney, minLot, maxLotCap);

      double scaledLot = baseLot;
      if(useMartingale)
      {
         LastTradeInfo last = GetLastTradeInfo();
         if(last.hasHistory && last.wasLoss && m_martingaleLevel < martMaxLvl)
         {
            m_martingaleLevel++;
            if(lotStep > 0)
               scaledLot = baseLot + (lotStep * m_martingaleLevel);
            else
               scaledLot = baseLot * MathPow(martMulti, m_martingaleLevel);
         }
         else if(last.hasHistory && !last.wasLoss)
         {
            m_martingaleLevel = 0;
         }
      }
      else
      {
         m_martingaleLevel = 0;
      }

      scaledLot = NormalizeLot(scaledLot);
      if(scaledLot < minLot) scaledLot = minLot;
      if(scaledLot > maxLotCap && maxLotCap > 0) scaledLot = maxLotCap;

      if(accType == ACCOUNT_PROP_FIRM || accType == ACCOUNT_FUNDED)
      {
         if(slDistPts > 0)
         {
            double tickVal = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSz  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
            double point   = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
            if(tickVal > 0 && tickSz > 0 && point > 0)
            {
               double valPerLotPt = tickVal * (point / tickSz);
               double potLoss = scaledLot * slDistPts * valPerLotPt;
               double dailyRemain = (m_dd.startingDayBalance * maxDailyDD / 100.0) -
                                    MathAbs(MathMin(m_dd.dailyPL, 0));
               if(dailyRemain > 0 && potLoss > dailyRemain * 0.8)
               {
                  double safeLot = (dailyRemain * 0.8) / (slDistPts * valPerLotPt);
                  scaledLot = NormalizeLot(MathMin(scaledLot, safeLot));
               }
            }
         }
      }

      m_lastBaseLot = baseLot;
      return NormalizeLot(scaledLot);
   }

   double CalcLotFromRisk(double slDist, ENUM_RISK_MODE mode, double fixLot,
                          double riskPct, double riskMon, double minL, double maxL)
   {
      if(mode == RISK_FIXED_LOT)
      {
         double l = fixLot;
         if(l < minL) l = minL;
         if(maxL > 0 && l > maxL) l = maxL;
         return NormalizeLot(l);
      }

      if(slDist <= 0) return NormalizeLot(fixLot);

      double tickVal = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSz  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double point   = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(tickVal <= 0 || tickSz <= 0 || point <= 0) return NormalizeLot(fixLot);

      double valPerLotPt = tickVal * (point / tickSz);
      double riskAmount = 0;

      switch(mode)
      {
         case RISK_PERCENT_BALANCE:     riskAmount = AccountInfoDouble(ACCOUNT_BALANCE)     * riskPct / 100.0; break;
         case RISK_PERCENT_EQUITY:      riskAmount = AccountInfoDouble(ACCOUNT_EQUITY)      * riskPct / 100.0; break;
         case RISK_FIXED_MONEY:         riskAmount = riskMon; break;
         case RISK_PERCENT_FREE_MARGIN: riskAmount = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * riskPct / 100.0; break;
         default: return NormalizeLot(fixLot);
      }

      if(riskAmount <= 0) return NormalizeLot(fixLot);

      double lots = riskAmount / (slDist * valPerLotPt);
      if(lots < minL) lots = minL;
      if(maxL > 0 && lots > maxL) lots = maxL;
      return NormalizeLot(lots);
   }

   void UpdateDrawdown(ENUM_ACCOUNT_TYPE accType, double maxDailyDD, double maxTotalDD,
                       double maxDailyProfit, bool trailingDD, bool martResetDaily)
   {
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);

      datetime todayStart = iTime(m_symbol, PERIOD_D1, 0);
      if(todayStart > m_dd.lastDayReset)
      {
         m_dd.startingDayBalance = balance;
         m_dd.dailyPL            = 0;
         m_dd.dailyLimitHit      = false;
         m_dd.lastDayReset       = todayStart;
         if(martResetDaily) m_martingaleLevel = 0;
      }

      m_dd.dailyPL = equity - m_dd.startingDayBalance;

      if(trailingDD && equity > m_dd.highWaterMark)
         m_dd.highWaterMark = equity;

      double ref = trailingDD ? m_dd.highWaterMark : m_dd.initialBalance;
      m_dd.totalDrawdown = ref - equity;

      if(accType == ACCOUNT_PROP_FIRM || accType == ACCOUNT_FUNDED)
      {
         double dailyLimit = m_dd.startingDayBalance * maxDailyDD / 100.0;
         if(m_dd.dailyPL <= -dailyLimit) m_dd.dailyLimitHit = true;

         double totalLimit = m_dd.initialBalance * maxTotalDD / 100.0;
         if(m_dd.totalDrawdown >= totalLimit) m_dd.totalLimitHit = true;

         if(maxDailyProfit > 0 && m_dd.dailyPL >= maxDailyProfit)
            m_dd.profitTargetHit = true;
      }
   }

   bool IsTradingAllowed(string &blockReason, ENUM_ACCOUNT_TYPE accType)
   {
      if(accType != ACCOUNT_PROP_FIRM && accType != ACCOUNT_FUNDED) return true;
      if(m_dd.totalLimitHit)  { blockReason = "TOTAL DD LIMIT — TRADING STOPPED"; return false; }
      if(m_dd.dailyLimitHit)  { blockReason = "DAILY DD LIMIT — PAUSED"; return false; }
      if(m_dd.profitTargetHit){ blockReason = "DAILY PROFIT TARGET REACHED"; return false; }
      return true;
   }

   LastTradeInfo GetLastTradeInfo()
   {
      LastTradeInfo info;
      info.hasHistory = false; info.wasLoss = false; info.wasBuy = false;
      info.lastLotSize = 0; info.consecutiveLosses = 0; info.consecutiveWins = 0; info.lastProfit = 0;

      if(!HistorySelect(0, TimeCurrent())) return info;

      int dealsTotal = HistoryDealsTotal();
      int cL = 0, cW = 0;
      bool foundLast = false, countL = true, countW = true;

      for(int i = dealsTotal - 1; i >= 0; i--)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol)     continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         if(!foundLast)
         {
            info.hasHistory = true;
            info.wasLoss    = (profit < 0);
            info.lastProfit = profit;

            ulong posId = (ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
            if(HistorySelectByPosition(posId))
            {
               int pd = HistoryDealsTotal();
               for(int j = 0; j < pd; j++)
               {
                  ulong et = HistoryDealGetTicket(j);
                  if(HistoryDealGetInteger(et, DEAL_ENTRY) == DEAL_ENTRY_IN &&
                     (int)HistoryDealGetInteger(et, DEAL_MAGIC) == m_magic &&
                     HistoryDealGetString(et, DEAL_SYMBOL) == m_symbol)
                  {
                     info.wasBuy      = (HistoryDealGetInteger(et, DEAL_TYPE) == DEAL_TYPE_BUY);
                     info.lastLotSize = HistoryDealGetDouble(et, DEAL_VOLUME);
                     break;
                  }
               }
               HistorySelect(0, TimeCurrent());
            }
            foundLast = true;
         }

         if(profit < 0) { if(countL) cL++; countW = false; }
         else           { if(countW) cW++; countL = false; }
         if(!countL && !countW) break;
      }
      info.consecutiveLosses = cL;
      info.consecutiveWins   = cW;
      return info;
   }

   void RecalcSessionStats()
   {
      ZeroMemory(m_stats);
      if(!HistorySelect(0, TimeCurrent())) return;
      datetime todayStart = iTime(m_symbol, PERIOD_D1, 0);
      int total = HistoryDealsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;

         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                       + HistoryDealGetDouble(ticket, DEAL_SWAP)
                       + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

         m_stats.totalTrades++;
         if(profit >= 0) { m_stats.wins++; m_stats.totalProfit += profit; }
         else            { m_stats.losses++; m_stats.totalLoss += MathAbs(profit); }

         datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(dt >= todayStart) m_stats.dailyPL += profit;
      }
   }

   int CountTradesToday()
   {
      int count = 0;
      if(!HistorySelect(0, TimeCurrent())) return 0;
      datetime todayStart = iTime(m_symbol, PERIOD_D1, 0);
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if((int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != m_magic) continue;
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != m_symbol) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         if(dt >= todayStart) count++;
      }
      return count;
   }

   DrawdownTracker GetDrawdownTracker() const { return m_dd; }
   SessionStats    GetSessionStats()    const { return m_stats; }
   int             GetMartingaleLevel() const { return m_martingaleLevel; }

   double GetDailyDDPercent()
   {
      if(m_dd.startingDayBalance <= 0) return 0;
      return (MathAbs(MathMin(m_dd.dailyPL, 0)) / m_dd.startingDayBalance) * 100.0;
   }

   double GetTotalDDPercent(bool trailing)
   {
      double ref = trailing ? m_dd.highWaterMark : m_dd.initialBalance;
      if(ref <= 0) return 0;
      return (MathMax(m_dd.totalDrawdown, 0) / ref) * 100.0;
   }
};

//╔═══════════════════════════════════════════════════════════════════╗
//║                     CLASS: CAPIHandler                          ║
//╚═══════════════════════════════════════════════════════════════════╝
class CAPIHandler
{
private:
   ENUM_AI_PROVIDER m_provider;
   ENUM_TIMEFRAMES  m_tf;
   string m_modelName;
   string m_apiURL;
   string m_symbol;
   int    m_magic;
   int    m_callsToday;
   datetime m_lastCallDay;
   string m_lastStatus;
   string m_apiKey;
   int    m_timeoutSec;
   int    m_chartWidth;
   int    m_chartHeight;
   int    m_chartBars;

   string m_tfEntryName;
   string m_tfMidName;
   string m_tfHighName;

   string JsonEscape(const string s)
   {
      string r = s;
      StringReplace(r, "\\", "\\\\"); StringReplace(r, "\"", "\\\"");
      StringReplace(r, "\n", "\\n");  StringReplace(r, "\r", "\\r");
      StringReplace(r, "\t", "\\t");
      return r;
   }

   string FileToBase64(const string filename)
   {
      int handle = FileOpen(filename, FILE_READ | FILE_BIN);
      if(handle == INVALID_HANDLE) return "";
      ulong fileSize = FileSize(handle);
      if(fileSize == 0) { FileClose(handle); return ""; }
      uchar raw[];
      ArrayResize(raw, (int)fileSize);
      uint bytesRead = FileReadArray(handle, raw, 0, (int)fileSize);
      FileClose(handle);
      if(bytesRead != (uint)fileSize) return "";
      uchar key[], enc[];
      if(CryptEncode(CRYPT_BASE64, raw, key, enc) <= 0) return "";
      string b64 = CharArrayToString(enc);
      StringReplace(b64, "\n", ""); StringReplace(b64, "\r", ""); StringReplace(b64, " ", "");
      return b64;
   }

   bool TakeScreenshot(ENUM_TIMEFRAMES tf, const string filename)
   {
      long chartId = ChartOpen(m_symbol, tf);
      if(chartId <= 0) return false;
      ChartSetInteger(chartId, CHART_SHOW_GRID, false);
      ChartSetInteger(chartId, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);
      ChartSetInteger(chartId, CHART_MODE, CHART_CANDLES);
      ChartSetInteger(chartId, CHART_COLOR_BACKGROUND, C'10,14,28');
      ChartSetInteger(chartId, CHART_COLOR_FOREGROUND, clrWhite);
      ChartSetInteger(chartId, CHART_COLOR_CANDLE_BULL, C'46,204,113');
      ChartSetInteger(chartId, CHART_COLOR_CANDLE_BEAR, C'231,76,60');
      ChartSetInteger(chartId, CHART_COLOR_CHART_UP, C'46,204,113');
      ChartSetInteger(chartId, CHART_COLOR_CHART_DOWN, C'231,76,60');
      ChartSetInteger(chartId, CHART_COLOR_GRID, C'30,35,55');
      ChartSetInteger(chartId, CHART_AUTOSCROLL, true);
      ChartSetInteger(chartId, CHART_SHOW_DATE_SCALE, true);
      ChartSetInteger(chartId, CHART_SHOW_PRICE_SCALE, true);
      ChartSetInteger(chartId, CHART_SHOW_PERIOD_SEP, true);
      ChartSetInteger(chartId, CHART_WIDTH_IN_BARS, m_chartBars);
      ChartRedraw(chartId);
      Sleep(2500);
      bool ok = ChartScreenShot(chartId, filename, m_chartWidth, m_chartHeight, ALIGN_RIGHT);
      ChartClose(chartId);
      return ok;
   }

   string GetSystemPrompt(ENUM_SLTP_MODE sltpMode, double fixSLpips, double fixTPpips,
                          int fixSLpts, int fixTPpts, double rrRatio)
   {
      string sltp_instruction = "";
      switch(sltpMode)
      {
         case SLTP_AI_DECIDES:
            sltp_instruction =
               "You MUST provide exact price levels for SL and TP. "
               "SL must be at a logical level: recent swing high/low, S/R zone, or structure level. "
               "TP must be at the next significant S/R zone. Minimum R:R = 1:1.5. ";
            break;
         case SLTP_FIXED_PIPS:
            sltp_instruction = StringFormat(
               "The EA will use fixed SL=%.0f pips and TP=%.0f pips. "
               "Still provide sl and tp in your JSON as 0.0 — the EA handles them. "
               "Focus your analysis on direction and confidence only. ",
               fixSLpips, fixTPpips);
            break;
         case SLTP_FIXED_POINTS:
            sltp_instruction = StringFormat(
               "The EA will use fixed SL=%d pts and TP=%d pts. "
               "Set sl and tp to 0.0 in your JSON. Focus on direction and confidence. ",
               fixSLpts, fixTPpts);
            break;
         case SLTP_AI_SL_RR:
            sltp_instruction = StringFormat(
               "Provide SL at a logical price level. TP will be calculated by the EA at R:R = 1:%.1f. "
               "Set tp to 0.0 in your JSON. ",
               rrRatio);
            break;
      }

      return
         "You are an expert forex/gold technical analyst AI integrated into a MetaTrader 5 trading robot. "
         "You receive 3 chart screenshots at different timeframes for the same symbol. "
         "ANALYSIS FRAMEWORK: "
         "Chart 3 (highest TF): overall bias, major S/R zones. "
         "Chart 2 (mid TF): market structure, swing highs/lows, trend patterns. "
         "Chart 1 (entry TF): entry timing, immediate S/R, candlestick patterns. "
         + sltp_instruction +
         "RESPOND ONLY in this exact JSON format: "
         "{\"direction\":\"BUY\" or \"SELL\" or \"NONE\","
         "\"confidence\":0-100,"
         "\"sl\":exact_price_level_or_0,"
         "\"tp\":exact_price_level_or_0,"
         "\"sl_reason\":\"brief reason\","
         "\"tp_reason\":\"brief reason\","
         "\"reason\":\"Overall analysis max 150 chars\"} "
         "RULES: "
         "- If charts conflict or are unclear, set direction to NONE. "
         "- Confidence: 90-100=textbook, 70-89=good, 50-69=marginal, below 50=skip. "
         "- Provide exact price levels, not pip distances.";
   }

   string GetUserPrompt(ENUM_PREFILTER_SIGNAL preSignal,
                        ENUM_TIMEFRAMES tfEntry,
                        ENUM_TIMEFRAMES tfMid,
                        ENUM_TIMEFRAMES tfHigh)
   {
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      string dir = (preSignal == SIGNAL_BULLISH) ? "BULLISH" : "BEARISH";

      return StringFormat(
         "Symbol: %s | Price: %s | Digits: %d | Point: %s | Pre-filter bias: %s. "
         "Chart 1 = %s (entry TF), Chart 2 = %s (confirmation TF), Chart 3 = %s (context TF). "
         "Analyze these 3 charts and confirm whether we should %s. JSON:",
         m_symbol,
         DoubleToString(bid, digits),
         digits,
         DoubleToString(point, digits),
         dir,
         TFName(tfEntry),
         TFName(tfMid),
         TFName(tfHigh),
         (preSignal == SIGNAL_BULLISH) ? "BUY" : "SELL"
      );
   }

   string BuildAnthropicReq(const string b64E, const string b64M, const string b64H,
                             const string uPrompt, const string sysPrompt)
   {
      string j = "{\"model\":\"" + m_modelName + "\",\"max_tokens\":500,";
      j += "\"system\":\"" + JsonEscape(sysPrompt) + "\",";
      j += "\"messages\":[{\"role\":\"user\",\"content\":[";
      j += "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"" + b64E + "\"}},";
      j += "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"" + b64M + "\"}},";
      j += "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"" + b64H + "\"}},";
      j += "{\"type\":\"text\",\"text\":\"" + JsonEscape(uPrompt) + "\"}]}]}";
      return j;
   }

   string BuildOpenAIReq(const string b64E, const string b64M, const string b64H,
                          const string uPrompt, const string sysPrompt)
   {
      string j = "{\"model\":\"" + m_modelName + "\",\"max_tokens\":500,";
      j += "\"messages\":[{\"role\":\"system\",\"content\":\"" + JsonEscape(sysPrompt) + "\"},";
      j += "{\"role\":\"user\",\"content\":[";
      j += "{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64," + b64E + "\"}},";
      j += "{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64," + b64M + "\"}},";
      j += "{\"type\":\"image_url\",\"image_url\":{\"url\":\"data:image/png;base64," + b64H + "\"}},";
      j += "{\"type\":\"text\",\"text\":\"" + JsonEscape(uPrompt) + "\"}]}]}";
      return j;
   }

   string BuildGoogleReq(const string b64E, const string b64M, const string b64H,
                          const string uPrompt, const string sysPrompt)
   {
      string fp = sysPrompt + " " + uPrompt;
      string j = "{\"contents\":[{\"parts\":[";
      j += "{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\"" + b64E + "\"}},";
      j += "{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\"" + b64M + "\"}},";
      j += "{\"inline_data\":{\"mime_type\":\"image/png\",\"data\":\"" + b64H + "\"}},";
      j += "{\"text\":\"" + JsonEscape(fp) + "\"}]}]}";
      return j;
   }

   string BuildHeaders()
   {
      string h = "Content-Type: application/json\r\n";
      switch(m_provider)
      {
         case PROVIDER_ANTHROPIC:
            h += "x-api-key: " + m_apiKey + "\r\n";
            h += "anthropic-version: 2023-06-01\r\n";
            break;
         case PROVIDER_OPENAI: case PROVIDER_DEEPSEEK: case PROVIDER_XAI:
            h += "Authorization: Bearer " + m_apiKey + "\r\n";
            break;
         default: break;
      }
      return h;
   }

   string GetRequestURL()
   {
      if(m_provider == PROVIDER_GOOGLE)
         return m_apiURL + "?key=" + m_apiKey;
      return m_apiURL;
   }

   string ExtractInnerText(const string response)
   {
      int startPos = StringFind(response, "\"text\":\"");
      if(startPos < 0) return "";
      startPos += 8;
      string result = "";
      bool escaped = false;
      int len = StringLen(response);
      for(int i = startPos; i < len && i < startPos + 20000; i++)
      {
         ushort ch = StringGetCharacter(response, i);
         if(escaped) {
            if(ch == '"') result += "\""; else if(ch == '\\') result += "\\";
            else if(ch == 'n') result += "\n"; else if(ch == 't') result += "\t";
            else if(ch == 'r') result += ""; else result += CharToString((uchar)ch);
            escaped = false;
         } else {
            if(ch == '\\') { escaped = true; continue; }
            if(ch == '"') break;
            result += CharToString((uchar)ch);
         }
      }
      return result;
   }

   string ExtractJsonString(const string json, const string key)
   {
      string search = "\"" + key + "\":\"";
      int pos = StringFind(json, search);
      if(pos < 0) { search = "\"" + key + "\": \""; pos = StringFind(json, search); }
      if(pos < 0) return "";
      pos += StringLen(search);
      string val = "";
      int len = StringLen(json);
      bool esc = false;
      for(int i = pos; i < len; i++)
      {
         ushort ch = StringGetCharacter(json, i);
         if(esc) { val += CharToString((uchar)ch); esc = false; continue; }
         if(ch == '\\') { esc = true; continue; }
         if(ch == '"') break;
         val += CharToString((uchar)ch);
      }
      return val;
   }

   int ExtractJsonInt(const string json, const string key)
   {
      string search = "\"" + key + "\":";
      int pos = StringFind(json, search);
      if(pos < 0) { search = "\"" + key + "\": "; pos = StringFind(json, search); }
      if(pos < 0) return 0;
      pos += StringLen(search);
      int len = StringLen(json);
      while(pos < len && StringGetCharacter(json, pos) == ' ') pos++;
      string digits = "";
      for(int i = pos; i < len; i++)
      {
         ushort ch = StringGetCharacter(json, i);
         if(ch >= '0' && ch <= '9') digits += CharToString((uchar)ch);
         else if(digits != "") break;
      }
      return digits == "" ? 0 : (int)StringToInteger(digits);
   }

   double ExtractJsonDouble(const string json, const string key)
   {
      string search = "\"" + key + "\":";
      int pos = StringFind(json, search);
      if(pos < 0) { search = "\"" + key + "\": "; pos = StringFind(json, search); }
      if(pos < 0) return 0;
      pos += StringLen(search);
      int len = StringLen(json);
      while(pos < len && StringGetCharacter(json, pos) == ' ') pos++;
      string numStr = "";
      for(int i = pos; i < len; i++)
      {
         ushort ch = StringGetCharacter(json, i);
         if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-') numStr += CharToString((uchar)ch);
         else if(numStr != "") break;
      }
      return numStr == "" ? 0 : StringToDouble(numStr);
   }

   bool ParseResponse(const string rawResponse, AIAnalysisResult &result)
   {
      result.Reset();
      string aiText = "";
      switch(m_provider)
      {
         case PROVIDER_ANTHROPIC: aiText = ExtractInnerText(rawResponse); break;
         case PROVIDER_OPENAI: case PROVIDER_DEEPSEEK: case PROVIDER_XAI:
         {
            int cp = StringFind(rawResponse, "\"content\":\"");
            if(cp >= 0) aiText = ExtractInnerText(StringSubstr(rawResponse, cp - 6));
            else aiText = rawResponse;
            break;
         }
         case PROVIDER_GOOGLE: aiText = ExtractInnerText(rawResponse); break;
         default: aiText = rawResponse; break;
      }
      if(aiText == "") aiText = rawResponse;
      Print("[API] AI raw: ", StringSubstr(aiText, 0, 300));

      string dirStr = ExtractJsonString(aiText, "direction");
      StringToUpper(dirStr);
      if(dirStr == "BUY") result.direction = AI_DIR_BUY;
      else if(dirStr == "SELL") result.direction = AI_DIR_SELL;
      else result.direction = AI_DIR_NONE;

      result.confidence = ExtractJsonInt(aiText, "confidence");
      result.slPrice    = ExtractJsonDouble(aiText, "sl");
      result.tpPrice    = ExtractJsonDouble(aiText, "tp");
      result.slReason   = ExtractJsonString(aiText, "sl_reason");
      result.tpReason   = ExtractJsonString(aiText, "tp_reason");
      result.reason     = ExtractJsonString(aiText, "reason");

      if(result.confidence <= 0 || result.confidence > 100) result.confidence = 50;
      result.isValid = true;
      return true;
   }

   ENUM_AI_PROVIDER DetectProvider(const string apiKey, const string provSel)
   {
      string sel = provSel;
      StringToLower(sel);
      if(sel == "anthropic") return PROVIDER_ANTHROPIC;
      if(sel == "openai")    return PROVIDER_OPENAI;
      if(sel == "google")    return PROVIDER_GOOGLE;
      if(sel == "deepseek")  return PROVIDER_DEEPSEEK;
      if(sel == "xai")       return PROVIDER_XAI;

      if(StringFind(apiKey, "sk-ant-") == 0) return PROVIDER_ANTHROPIC;
      if(StringFind(apiKey, "xai-") == 0)    return PROVIDER_XAI;
      if(StringFind(apiKey, "AI") == 0)      return PROVIDER_GOOGLE;
      if(StringFind(apiKey, "sk-proj-") == 0 || StringLen(apiKey) > 80) return PROVIDER_OPENAI;
      if(StringFind(apiKey, "sk-") == 0)     return PROVIDER_OPENAI;
      return PROVIDER_UNKNOWN;
   }

public:
   CAPIHandler() : m_provider(PROVIDER_UNKNOWN), m_tf(PERIOD_M15),
                   m_callsToday(0), m_lastCallDay(0),
                   m_tfEntryName("M15"), m_tfMidName("H1"), m_tfHighName("H4") {}

   bool Init(const string symbol, int magic, const string apiKey, const string provOverride,
             int timeout, int chartW, int chartH, int chartBars,
             ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol; m_magic = magic; m_apiKey = apiKey;
      m_timeoutSec = timeout; m_chartWidth = chartW; m_chartHeight = chartH; m_chartBars = chartBars;
      m_tf = tf;

      if(m_apiKey == "") { m_lastStatus = "ERROR: API Key empty"; return false; }

      m_provider = DetectProvider(m_apiKey, provOverride);
      if(m_provider == PROVIDER_UNKNOWN) { m_lastStatus = "Unknown key format"; return false; }

      switch(m_provider)
      {
         case PROVIDER_ANTHROPIC: m_modelName = MODEL_ANTHROPIC; m_apiURL = URL_ANTHROPIC; break;
         case PROVIDER_OPENAI:    m_modelName = MODEL_OPENAI;    m_apiURL = URL_OPENAI;    break;
         case PROVIDER_GOOGLE:    m_modelName = MODEL_GOOGLE;    m_apiURL = URL_GOOGLE;    break;
         case PROVIDER_DEEPSEEK:  m_modelName = MODEL_DEEPSEEK;  m_apiURL = URL_DEEPSEEK;  break;
         case PROVIDER_XAI:       m_modelName = MODEL_XAI;       m_apiURL = URL_XAI;       break;
         default: break;
      }

      ENUM_TIMEFRAMES tfE, tfM, tfH;
      GetScreenshotTimeframes(m_tf, tfE, tfM, tfH);
      m_tfEntryName = TFName(tfE);
      m_tfMidName   = TFName(tfM);
      m_tfHighName  = TFName(tfH);

      m_lastStatus = StringFormat("Ready — %s | TFs: %s/%s/%s",
         EnumToString(m_provider), m_tfEntryName, m_tfMidName, m_tfHighName);

      PrintFormat("[API] Provider=%s | Model=%s | TF stack: %s / %s / %s",
         EnumToString(m_provider), m_modelName, m_tfEntryName, m_tfMidName, m_tfHighName);

      return true;
   }

   bool AnalyzeCharts(ENUM_PREFILTER_SIGNAL preSignal, AIAnalysisResult &result,
                      ENUM_SLTP_MODE sltpMode, double fixSLpips, double fixTPpips,
                      int fixSLpts, int fixTPpts, double rrRatio)
   {
      result.Reset();
      datetime today = iTime(m_symbol, PERIOD_D1, 0);
      if(today > m_lastCallDay) { m_callsToday = 0; m_lastCallDay = today; }

      ENUM_TIMEFRAMES tfEntry, tfMid, tfHigh;
      GetScreenshotTimeframes(m_tf, tfEntry, tfMid, tfHigh);
      m_tfEntryName = TFName(tfEntry);
      m_tfMidName   = TFName(tfMid);
      m_tfHighName  = TFName(tfHigh);

      PrintFormat("[API] Capturing screenshots: Entry=%s | Mid=%s | High=%s",
         m_tfEntryName, m_tfMidName, m_tfHighName);

      m_lastStatus = StringFormat("Capturing %s/%s/%s...", m_tfEntryName, m_tfMidName, m_tfHighName);

      string pfx   = "AIV_" + m_symbol + "_" + IntegerToString(m_magic) + "_";
      string fEntry = pfx + m_tfEntryName + ".png";
      string fMid   = pfx + m_tfMidName   + ".png";
      string fHigh  = pfx + m_tfHighName  + ".png";

      if(!TakeScreenshot(tfEntry, fEntry))
      {
         m_lastStatus = m_tfEntryName + " screenshot fail";
         return false;
      }
      if(!TakeScreenshot(tfMid, fMid))
      {
         m_lastStatus = m_tfMidName + " screenshot fail";
         FileDelete(fEntry);
         return false;
      }
      if(!TakeScreenshot(tfHigh, fHigh))
      {
         m_lastStatus = m_tfHighName + " screenshot fail";
         FileDelete(fEntry); FileDelete(fMid);
         return false;
      }

      m_lastStatus = "Encoding...";
      string b64Entry = FileToBase64(fEntry);
      string b64Mid   = FileToBase64(fMid);
      string b64High  = FileToBase64(fHigh);

      FileDelete(fEntry); FileDelete(fMid); FileDelete(fHigh);

      if(b64Entry == "" || b64Mid == "" || b64High == "")
      {
         m_lastStatus = "Encoding failed";
         return false;
      }

      m_lastStatus = "Calling " + EnumToString(m_provider) + "...";

      string sysP = GetSystemPrompt(sltpMode, fixSLpips, fixTPpips, fixSLpts, fixTPpts, rrRatio);
      string uP   = GetUserPrompt(preSignal, tfEntry, tfMid, tfHigh);
      string payload = "";

      switch(m_provider)
      {
         case PROVIDER_ANTHROPIC:
            payload = BuildAnthropicReq(b64Entry, b64Mid, b64High, uP, sysP);
            break;
         case PROVIDER_OPENAI: case PROVIDER_DEEPSEEK: case PROVIDER_XAI:
            payload = BuildOpenAIReq(b64Entry, b64Mid, b64High, uP, sysP);
            break;
         case PROVIDER_GOOGLE:
            payload = BuildGoogleReq(b64Entry, b64Mid, b64High, uP, sysP);
            break;
         default:
            m_lastStatus = "Unknown provider";
            return false;
      }

      string headers = BuildHeaders();
      string url = GetRequestURL();
      uchar postBytes[];
      int copyLen = StringToCharArray(payload, postBytes, 0, WHOLE_ARRAY, CP_UTF8) - 1;
      if(copyLen > 0) ArrayResize(postBytes, copyLen);

      uchar respBytes[];
      string respHeaders;
      int httpCode = WebRequest("POST", url, headers, m_timeoutSec * 1000, postBytes, respBytes, respHeaders);

      if(httpCode == -1)
      {
         m_lastStatus = StringFormat("WebRequest fail (err %d)", GetLastError());
         return false;
      }

      string body = CharArrayToString(respBytes, 0, WHOLE_ARRAY, CP_UTF8);
      if(httpCode != 200)
      {
         m_lastStatus = StringFormat("HTTP %d", httpCode);
         PrintFormat("[API] HTTP %d | Body: %s", httpCode, StringSubstr(body, 0, 200));
         return false;
      }

      m_lastStatus = "Parsing...";
      if(!ParseResponse(body, result)) { m_lastStatus = "Parse failed"; return false; }

      m_callsToday++;
      m_lastStatus = StringFormat("%s %d%% [%s/%s/%s]",
         (result.direction == AI_DIR_BUY) ? "BUY" :
         (result.direction == AI_DIR_SELL) ? "SELL" : "NONE",
         result.confidence,
         m_tfEntryName, m_tfMidName, m_tfHighName);

      return true;
   }

   ENUM_AI_PROVIDER GetProvider()     const { return m_provider; }
   string           GetModelName()    const { return m_modelName; }
   int              GetCallsToday()   const { return m_callsToday; }
   string           GetLastStatus()   const { return m_lastStatus; }
   string           GetTFEntryName()  const { return m_tfEntryName; }
   string           GetTFMidName()    const { return m_tfMidName; }
   string           GetTFHighName()   const { return m_tfHighName; }
};

//╔═══════════════════════════════════════════════════════════════════╗
//║                     CLASS: CTradeManager                        ║
//╚═══════════════════════════════════════════════════════════════════╝
class CTradeManager
{
private:
   CTrade   m_trade;
   string   m_symbol;
   int      m_magic;
   int      m_handleATR;
   bool     m_partial1Done;
   bool     m_partial2Done;

   ENUM_ORDER_TYPE_FILLING DetectFillType()
   {
      long fp = SymbolInfoInteger(m_symbol, SYMBOL_FILLING_MODE);
      if((fp & SYMBOL_FILLING_FOK) != 0) return ORDER_FILLING_FOK;
      if((fp & SYMBOL_FILLING_IOC) != 0) return ORDER_FILLING_IOC;
      return ORDER_FILLING_RETURN;
   }

   void Notify(const string msg, bool doAlert, bool doPush, bool doEmail)
   {
      PrintFormat("[Trade] %s", msg);
      if(doAlert) Alert(AIV_EA_NAME + ": " + msg);
      if(doPush)  SendNotification(AIV_EA_NAME + ": " + msg);
      if(doEmail) SendMail(AIV_EA_NAME + " Alert", msg);
   }

public:
   CTradeManager() : m_handleATR(INVALID_HANDLE), m_partial1Done(false), m_partial2Done(false) {}

   bool Init(const string symbol, int magic, bool useTrail, ENUM_TRAIL_MODE trailMode, int atrPeriod)
   {
      m_symbol = symbol; m_magic = magic;
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(30);
      m_trade.SetTypeFilling(DetectFillType());

      if(useTrail && trailMode == TRAIL_ATR)
      {
         m_handleATR = iATR(m_symbol, PERIOD_M15, atrPeriod);
         if(m_handleATR == INVALID_HANDLE)
            PrintFormat("[Trade] ATR handle fail, fallback to fixed trail");
      }
      return true;
   }

   void Deinit()
   {
      if(m_handleATR != INVALID_HANDLE) { IndicatorRelease(m_handleATR); m_handleATR = INVALID_HANDLE; }
   }

   bool HasOpenPosition()
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && (int)PositionGetInteger(POSITION_MAGIC) == m_magic) return true;
      }
      return false;
   }

   ulong GetPositionTicket()
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) == m_symbol && (int)PositionGetInteger(POSITION_MAGIC) == m_magic) return t;
      }
      return 0;
   }

   bool ExecuteTrade(const AIAnalysisResult &ai, double lotSize,
                     ENUM_SLTP_MODE sltpMode, double fixSLpips, double fixTPpips,
                     int fixSLpts, int fixTPpts, double rrRatio,
                     double pipMult, double minSLpips, double maxSLpips,
                     bool doAlert, bool doPush, bool doEmail)
   {
      if(ai.direction == AI_DIR_NONE) return false;

      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      int minStop = (int)SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);

      double sl = 0, tp = 0;

      switch(sltpMode)
      {
         case SLTP_AI_DECIDES: sl = ai.slPrice; tp = ai.tpPrice; break;
         case SLTP_FIXED_PIPS:
            if(ai.direction == AI_DIR_BUY) { sl = ask - fixSLpips * pipMult * point; tp = ask + fixTPpips * pipMult * point; }
            else                           { sl = bid + fixSLpips * pipMult * point; tp = bid - fixTPpips * pipMult * point; }
            break;
         case SLTP_FIXED_POINTS:
            if(ai.direction == AI_DIR_BUY) { sl = ask - fixSLpts * point; tp = ask + fixTPpts * point; }
            else                           { sl = bid + fixSLpts * point; tp = bid - fixTPpts * point; }
            break;
         case SLTP_AI_SL_RR:
            sl = ai.slPrice;
            if(ai.direction == AI_DIR_BUY) { double d = ask - sl; tp = ask + d * rrRatio; }
            else                           { double d = sl - bid; tp = bid - d * rrRatio; }
            break;
      }

      sl = NormalizeDouble(sl, digits);
      tp = NormalizeDouble(tp, digits);

      double slDistPips = 0;
      if(ai.direction == AI_DIR_BUY) slDistPips = (ask - sl) / (pipMult * point);
      else                           slDistPips = (sl - bid) / (pipMult * point);

      if(slDistPips < minSLpips && minSLpips > 0)
      {
         if(ai.direction == AI_DIR_BUY) sl = NormalizeDouble(ask - minSLpips * pipMult * point, digits);
         else                           sl = NormalizeDouble(bid + minSLpips * pipMult * point, digits);
      }
      if(slDistPips > maxSLpips && maxSLpips > 0)
      {
         if(ai.direction == AI_DIR_BUY) sl = NormalizeDouble(ask - maxSLpips * pipMult * point, digits);
         else                           sl = NormalizeDouble(bid + maxSLpips * pipMult * point, digits);
      }

      double slDistPts = (ai.direction == AI_DIR_BUY) ? (ask - sl) / point : (sl - bid) / point;
      if(slDistPts < minStop && minStop > 0)
      {
         if(ai.direction == AI_DIR_BUY) sl = NormalizeDouble(ask - (minStop + 5) * point, digits);
         else                           sl = NormalizeDouble(bid + (minStop + 5) * point, digits);
      }

      string comment = StringFormat("AIV_%d_%d%%", m_magic, ai.confidence);
      bool opened = false;
      if(ai.direction == AI_DIR_BUY) opened = m_trade.Buy(lotSize, m_symbol, ask, sl, tp, comment);
      else                           opened = m_trade.Sell(lotSize, m_symbol, bid, sl, tp, comment);

      if(opened && m_trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         string msg = StringFormat("%s %s %.2f @ %s SL=%s TP=%s AI=%d%%",
            (ai.direction == AI_DIR_BUY) ? "BUY" : "SELL", m_symbol, lotSize,
            DoubleToString(ai.direction == AI_DIR_BUY ? ask : bid, digits),
            DoubleToString(sl, digits), DoubleToString(tp, digits), ai.confidence);
         Notify(msg, doAlert, doPush, doEmail);
         m_partial1Done = false; m_partial2Done = false;
         return true;
      }
      else
      {
         Notify(StringFormat("FAIL: %d %s", m_trade.ResultRetcode(), m_trade.ResultRetcodeDescription()),
                doAlert, doPush, doEmail);
         return false;
      }
   }

   void ManageTrailingStop(bool useTrail, ENUM_TRAIL_MODE trailMode,
                           double trailDistPips, double bePips,
                           double atrMult, double pipMult)
   {
      if(!useTrail) return;
      ulong ticket = GetPositionTicket();
      if(ticket == 0) return;
      if(!PositionSelectByTicket(ticket)) return;

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double curSL = PositionGetDouble(POSITION_SL);
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp = PositionGetDouble(POSITION_TP);
      long posType = PositionGetInteger(POSITION_TYPE);

      double trailPts = trailDistPips * pipMult;
      if(trailMode == TRAIL_ATR && m_handleATR != INVALID_HANDLE)
      {
         double atr[];
         if(CopyBuffer(m_handleATR, 0, 0, 1, atr) >= 1)
            trailPts = (atr[0] * atrMult) / point;
      }

      double newSL = 0;
      if(posType == POSITION_TYPE_BUY)
      {
         if(trailMode == TRAIL_BREAKEVEN_PLUS)
         {
            double beL = NormalizeDouble(openP + bePips * pipMult * point, digits);
            if(bid > openP + trailPts * point && curSL < beL) newSL = beL;
         }
         else
         {
            double tL = NormalizeDouble(bid - trailPts * point, digits);
            if(bid > openP + trailPts * point && tL > curSL) newSL = tL;
         }
      }
      else
      {
         if(trailMode == TRAIL_BREAKEVEN_PLUS)
         {
            double beL = NormalizeDouble(openP - bePips * pipMult * point, digits);
            if(ask < openP - trailPts * point && (curSL > beL || curSL == 0)) newSL = beL;
         }
         else
         {
            double tL = NormalizeDouble(ask + trailPts * point, digits);
            if(ask < openP - trailPts * point && (tL < curSL || curSL == 0)) newSL = tL;
         }
      }

      if(newSL != 0 && newSL != curSL) m_trade.PositionModify(ticket, newSL, tp);
   }

   void ManagePartialClose(bool usePart, double p1Pct, double p1RR, double p2Pct, double p2RR)
   {
      if(!usePart) return;
      ulong ticket = GetPositionTicket();
      if(ticket == 0) return;
      if(!PositionSelectByTicket(ticket)) return;

      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double openP = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      long posType = PositionGetInteger(POSITION_TYPE);

      if(sl == 0 || vol <= 0) return;
      double riskDist = MathAbs(openP - sl);
      if(riskDist <= 0) return;
      double curPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double profDist = (posType == POSITION_TYPE_BUY) ? (curPrice - openP) : (openP - curPrice);
      double curRR = profDist / riskDist;

      if(!m_partial1Done && curRR >= p1RR)
      {
         double cLots = NormPartLots(vol * p1Pct / 100.0);
         if(cLots > 0 && cLots < vol && m_trade.PositionClosePartial(ticket, cLots))
            m_partial1Done = true;
      }
      if(!m_partial2Done && m_partial1Done && curRR >= p2RR)
      {
         if(!PositionSelectByTicket(ticket)) return;
         vol = PositionGetDouble(POSITION_VOLUME);
         double cLots = NormPartLots(vol * p2Pct / 100.0 / (1.0 - p1Pct / 100.0));
         if(cLots > 0 && cLots < vol && m_trade.PositionClosePartial(ticket, cLots))
            m_partial2Done = true;
      }
   }

   double NormPartLots(double lots)
   {
      double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      lots = MathFloor(lots / lotStep) * lotStep;
      if(lots < minLot) return 0;
      return NormalizeDouble(lots, 2);
   }

   void CloseAllPositions(bool doAlert, bool doPush, bool doEmail)
   {
      for(int i = PositionsTotal()-1; i >= 0; i--)
      {
         ulong t = PositionGetTicket(i);
         if(!PositionSelectByTicket(t)) continue;
         if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != m_magic) continue;
         m_trade.PositionClose(t);
      }
      Notify("All positions closed for " + m_symbol, doAlert, doPush, doEmail);
   }

   bool GetPositionInfo(string &type, double &lots, double &sl, double &tp, double &pl)
   {
      ulong ticket = GetPositionTicket();
      if(ticket == 0) return false;
      if(!PositionSelectByTicket(ticket)) return false;
      type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      lots = PositionGetDouble(POSITION_VOLUME);
      sl   = PositionGetDouble(POSITION_SL);
      tp   = PositionGetDouble(POSITION_TP);
      pl   = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      return true;
   }

   double GetSLDistancePoints(const AIAnalysisResult &ai, ENUM_SLTP_MODE mode,
                              double fixSLpips, int fixSLpts, double pipMult)
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      switch(mode)
      {
         case SLTP_AI_DECIDES: case SLTP_AI_SL_RR:
         {
            if(ai.slPrice <= 0) return fixSLpips * pipMult;
            return (ai.direction == AI_DIR_BUY) ? (ask - ai.slPrice) / point : (ai.slPrice - bid) / point;
         }
         case SLTP_FIXED_PIPS:   return fixSLpips * pipMult;
         case SLTP_FIXED_POINTS: return (double)fixSLpts;
      }
      return fixSLpips * pipMult;
   }
};

//╔═══════════════════════════════════════════════════════════════════╗
//║                      CLASS: CAIVPanel                           ║
//╚═══════════════════════════════════════════════════════════════════╝
class CAIVPanel
{
private:
   string      m_prefix;
   bool        m_minimized;
   int         m_panelHeight;
   int         m_cursorY;
   int         m_baseX;
   int         m_baseY;
   ENUM_BASE_CORNER m_corner;
   bool        m_lastActiveState;
   PanelConfig m_cfg;
   int         m_valX;

   bool   m_dragging;
   int    m_dragStartMouseX;
   int    m_dragStartMouseY;
   int    m_dragStartPanelX;
   int    m_dragStartPanelY;

   void CreateBgRect(const string name, int x, int y, int w, int h, color bg, color border)
   {
      string n = m_prefix + name;
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(0, n, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   }

   void CreateRect(const string name, int x, int y, int w, int h, color bg, color border)
   {
      string n = m_prefix + name;
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
      ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, border);
      ObjectSetInteger(0, n, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 1);
   }

   void CreateLabel(const string name, const string text, int x, int y,
                    color clr, int fontSize, const string font = "")
   {
      string n = m_prefix + name;
      string useFont = (font != "") ? font : m_cfg.fontData;
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, n, OBJPROP_TEXT, text);
      ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fontSize);
      ObjectSetString(0, n, OBJPROP_FONT, useFont);
      ObjectSetInteger(0, n, OBJPROP_CORNER, m_corner);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_BACK, false);
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_ZORDER, 2);
   }

   void UpdateLabel(const string name, const string text, color clr = 0)
   {
      string n = m_prefix + name;
      ObjectSetString(0, n, OBJPROP_TEXT, text);
      if(clr != 0) ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   }

   void UpdateRect(const string name, color bg, color border)
   {
      string n = m_prefix + name;
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
      ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, border);
   }

   void CreateProgressBar(const string name, int x, int y, int w, int h)
   {
      CreateRect(name + "_bg",   x, y, w, h, m_cfg.clrProgressBg, m_cfg.clrProgressBg);
      CreateRect(name + "_fill", x, y, 1, h, m_cfg.clrBullish, m_cfg.clrBullish);
   }

   void UpdateProgressBar(const string name, double pct, int fullWidth, color fillClr)
   {
      if(pct < 0) pct = 0; if(pct > 100) pct = 100;
      int fillW = (int)(fullWidth * pct / 100.0);
      if(fillW < 1) fillW = 1;
      string n = m_prefix + name + "_fill";
      ObjectSetInteger(0, n, OBJPROP_XSIZE, fillW);
      ObjectSetInteger(0, n, OBJPROP_BGCOLOR, fillClr);
      ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, fillClr);
   }

   void AddSectionHeader(const string id, const string text)
   {
      m_cursorY += 3;
      CreateRect("sec_" + id, m_baseX, m_cursorY, m_cfg.panelWidth, PANEL_ROW_HEIGHT + 2,
                 m_cfg.clrSectionHdr, m_cfg.clrBorder);
      CreateLabel("seclbl_" + id, "  " + text, m_baseX + 2, m_cursorY + 2,
                  m_cfg.clrAccent, m_cfg.fontSizeHeader, m_cfg.fontHeader);
      m_cursorY += PANEL_ROW_HEIGHT + 4;
   }

   void AddDataRow(const string id, const string label, const string value, color valClr = 0)
   {
      if(valClr == 0) valClr = m_cfg.clrTextPrimary;
      CreateLabel("lbl_" + id, label, m_baseX + PANEL_PADDING, m_cursorY,
                  m_cfg.clrTextSecondary, m_cfg.fontSizeData);
      CreateLabel("val_" + id, value, m_baseX + m_valX, m_cursorY,
                  valClr, m_cfg.fontSizeData);
      m_cursorY += PANEL_ROW_HEIGHT;
   }

   void MoveAllObjects(int dx, int dy)
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_prefix) != 0) continue;
         int curX = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
         int curY = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, curX + dx);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, curY + dy);
      }
      m_baseX += dx;
      m_baseY += dy;
   }

   bool IsOverHeader(int mouseX, int mouseY)
   {
      return (mouseX >= m_baseX && mouseX <= m_baseX + m_cfg.panelWidth &&
              mouseY >= m_baseY && mouseY <= m_baseY + 36);
   }

public:
   CAIVPanel() : m_minimized(false), m_panelHeight(0), m_cursorY(0),
              m_lastActiveState(true), m_dragging(false), m_valX(155) {}

   string GetPrefix() const { return m_prefix; }

   void Create(ENUM_BASE_CORNER corner, int panelX, int panelY, bool showPropFirm,
               const PanelConfig &config)
   {
      m_corner = corner;
      m_cfg    = config;
      m_prefix = "AIV3_" + IntegerToString(ChartID()) + "_";
      m_baseX  = panelX;
      m_baseY  = panelY;
      m_cursorY = m_baseY;

      m_valX = (int)(m_cfg.panelWidth * 0.48);
      int pbarWidth = m_cfg.panelWidth - m_valX - PANEL_PADDING;

      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);

      CreateBgRect("body_bg", m_baseX, m_baseY, m_cfg.panelWidth, 700,
                   m_cfg.clrBackground, m_cfg.clrBorder);

      int headerH = 36;
      CreateRect("header", m_baseX, m_cursorY, m_cfg.panelWidth, headerH,
                 m_cfg.clrHeader, m_cfg.clrAccent);
      CreateLabel("title", "PRIME QUANTUM AI", m_baseX + PANEL_PADDING, m_cursorY + 4,
                  m_cfg.clrAccent, m_cfg.fontSizeTitle, m_cfg.fontHeader);
      CreateLabel("ver", "v" + AIV_VERSION, m_baseX + PANEL_PADDING, m_cursorY + 22,
                  m_cfg.clrTextMuted, 6);
      CreateLabel("timemode", m_cfg.timeModeLabel,
                  m_baseX + m_cfg.panelWidth - 90, m_cursorY + 12,
                  m_cfg.clrTextMuted, PANEL_FONT_SIZE_BRAND, m_cfg.fontHeader);
      CreateLabel("btn_min",   "━", m_baseX + m_cfg.panelWidth - 38, m_cursorY + 12,
                  m_cfg.clrTextSecondary, 10, "Arial Bold");
      CreateLabel("btn_close", "x", m_baseX + m_cfg.panelWidth - 18, m_cursorY + 12,
                  m_cfg.clrBearish, 9, "Arial Bold");
      m_cursorY += headerH + 2;

      CreateRect("status_bar", m_baseX, m_cursorY, m_cfg.panelWidth, 20,
                 C'10,40,20', m_cfg.clrBorder);
      CreateLabel("status_icon", CharToString(0x25CF), m_baseX + PANEL_PADDING, m_cursorY + 3,
                  m_cfg.clrBullish, 10, "Arial");
      CreateLabel("status_text", "ACTIVE — Monitoring", m_baseX + 26, m_cursorY + 4,
                  m_cfg.clrBullish, 8, m_cfg.fontHeader);
      m_cursorY += 22;

      AddSectionHeader("acct", "ACCOUNT");
      AddDataRow("balance",  "Balance:",      "---");
      AddDataRow("equity",   "Equity:",       "---");
      AddDataRow("margin",   "Free Margin:",  "---");
      AddDataRow("dailypl",  "Daily P/L:",    "---");

      AddSectionHeader("sym", "SYMBOL INFO");
      AddDataRow("bidask", "Bid / Ask:", "---");
      AddDataRow("spread", "Spread:",    "---");

      AddSectionHeader("ai", "AI ENGINE");
      AddDataRow("provider",  "Provider:",    "---");
      AddDataRow("tfsuite",   "TF Suite:",    "---");
      AddDataRow("aicalls",   "API Calls:",   "---");
      AddDataRow("aistatus",  "Status:",      "---");
      AddDataRow("aidecis",   "Decision:",    "---");
      AddDataRow("aiconf",    "Confidence:",  "---");
      AddDataRow("aireason",  "Reason:",      "---");

      AddSectionHeader("trd", "ACTIVE TRADE");
      AddDataRow("position", "Position:", "---");
      AddDataRow("sltp",     "SL / TP:",  "---");
      AddDataRow("tradepl",  "Trade P/L:","---");
      AddDataRow("trades",   "Today W/L:","---");

      AddSectionHeader("risk", "RISK MANAGEMENT");
      AddDataRow("riskmode", "Mode:",       "---");
      AddDataRow("nextlot",  "Next Lot:",   "---");
      AddDataRow("martlvl",  "Martingale:", "---");

      if(showPropFirm)
      {
         AddSectionHeader("prop", "PROP FIRM GUARD");
         AddDataRow("propdaily", "Daily DD:", "---");
         CreateProgressBar("pbar_daily", m_baseX + m_valX, m_cursorY - PANEL_ROW_HEIGHT + 12, pbarWidth, 5);
         AddDataRow("proptotal", "Total DD:", "---");
         CreateProgressBar("pbar_total", m_baseX + m_valX, m_cursorY - PANEL_ROW_HEIGHT + 12, pbarWidth, 5);
      }

      AddSectionHeader("info", "INFO");
      AddDataRow("clock",    "Clock:",     "---");
      AddDataRow("news",     "Next News:", "---");
      AddDataRow("nextscan", "Next Scan:", "---");

      m_cursorY += 2;
      CreateRect("footer", m_baseX, m_cursorY, m_cfg.panelWidth, 18,
                 m_cfg.clrHeader, m_cfg.clrAccent);
      CreateLabel("foottime", "Updated: --:--:--", m_baseX + PANEL_PADDING, m_cursorY + 3,
                  m_cfg.clrTextMuted, 7);
      CreateLabel("footconn", CharToString(0x25CF), m_baseX + m_cfg.panelWidth - 20, m_cursorY + 3,
                  m_cfg.clrBullish, 10, "Arial");
      m_cursorY += 20;

      m_panelHeight = m_cursorY - m_baseY;
      string bgName = m_prefix + "body_bg";
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, m_panelHeight);

      ChartRedraw();
   }

   void Update(const PanelData &d)
   {
      if(m_minimized) return;

      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      int pbarWidth = m_cfg.panelWidth - m_valX - PANEL_PADDING;

      if(d.eaActive != m_lastActiveState)
      {
         m_lastActiveState = d.eaActive;
         if(!d.eaActive)
         {
            UpdateRect("header", m_cfg.clrInactiveHdr, m_cfg.clrWarning);
            string bgN = m_prefix + "body_bg";
            ObjectSetInteger(0, bgN, OBJPROP_BGCOLOR, m_cfg.clrInactiveBg);
            ObjectSetInteger(0, bgN, OBJPROP_BORDER_COLOR, m_cfg.clrInactiveBorder);
            UpdateRect("footer", m_cfg.clrInactiveHdr, m_cfg.clrWarning);
            UpdateRect("status_bar", C'50,40,10', m_cfg.clrInactiveBorder);
            UpdateLabel("title", "PRIME QUANTUM AI", m_cfg.clrWarning);
         }
         else
         {
            UpdateRect("header", m_cfg.clrHeader, m_cfg.clrAccent);
            string bgN = m_prefix + "body_bg";
            ObjectSetInteger(0, bgN, OBJPROP_BGCOLOR, m_cfg.clrBackground);
            ObjectSetInteger(0, bgN, OBJPROP_BORDER_COLOR, m_cfg.clrBorder);
            UpdateRect("footer", m_cfg.clrHeader, m_cfg.clrAccent);
            UpdateRect("status_bar", C'10,40,20', m_cfg.clrBorder);
            UpdateLabel("title", "PRIME QUANTUM AI", m_cfg.clrAccent);
         }
      }

      if(d.eaActive)
      {
         UpdateLabel("status_icon", CharToString(0x25CF), m_cfg.clrBullish);
         UpdateLabel("status_text", "ACTIVE — Scanning", m_cfg.clrBullish);
      }
      else
      {
         UpdateLabel("status_icon", CharToString(0x25CF), m_cfg.clrWarning);
         string reason = d.blockReason;
         if(StringLen(reason) > 38) reason = StringSubstr(reason, 0, 38) + "..";
         UpdateLabel("status_text", "PAUSED — " + reason, m_cfg.clrWarning);
      }

      UpdateLabel("val_balance", DoubleToString(d.balance, 2));
      UpdateLabel("val_equity",  DoubleToString(d.equity, 2));
      UpdateLabel("val_margin",  DoubleToString(d.freeMargin, 2));
      UpdateLabel("val_dailypl", (d.dailyPL >= 0 ? "+" : "") + DoubleToString(d.dailyPL, 2),
                  d.dailyPL >= 0 ? m_cfg.clrBullish : m_cfg.clrBearish);

      UpdateLabel("val_bidask", DoubleToString(d.bid, digits) + " / " + DoubleToString(d.ask, digits));
      color spClr = (d.spreadPoints > 20) ? m_cfg.clrBearish :
                    (d.spreadPoints > 10) ? m_cfg.clrWarning : m_cfg.clrBullish;
      UpdateLabel("val_spread", IntegerToString(d.spreadPoints) + " pts", spClr);

      UpdateLabel("val_provider", d.modelName != "" ? d.modelName : "Not Set");

      UpdateLabel("val_tfsuite",
         d.tfEntryName + " / " + d.tfMidName + " / " + d.tfHighName,
         m_cfg.clrAccent);

      UpdateLabel("val_aicalls", IntegerToString(d.apiCallsToday) +
                  " (~$" + DoubleToString(d.apiCallsToday * COST_PER_CALL, 2) + ")");
      UpdateLabel("val_aistatus", d.aiStatus);
      UpdateLabel("val_aidecis", d.lastDecision,
                  d.lastDecision == "BUY" ? m_cfg.clrBullish :
                  d.lastDecision == "SELL" ? m_cfg.clrBearish : m_cfg.clrTextSecondary);
      UpdateLabel("val_aiconf", IntegerToString(d.lastConfidence) + "%",
                  d.lastConfidence >= 80 ? m_cfg.clrBullish :
                  d.lastConfidence >= 60 ? m_cfg.clrWarning : m_cfg.clrBearish);

      int maxReasonChars = (int)(m_cfg.panelWidth - m_valX - PANEL_PADDING) / 6;
      string dr = d.lastReason;
      if(StringLen(dr) > maxReasonChars) dr = StringSubstr(dr, 0, maxReasonChars) + "..";
      UpdateLabel("val_aireason", dr);

      if(d.hasPosition)
      {
         UpdateLabel("val_position", d.positionType + " " + DoubleToString(d.positionLots, 2) + " lots",
                     d.positionType == "BUY" ? m_cfg.clrBullish : m_cfg.clrBearish);
         UpdateLabel("val_sltp", DoubleToString(d.positionSL, digits) + " / " + DoubleToString(d.positionTP, digits));
         UpdateLabel("val_tradepl", (d.positionPL >= 0 ? "+" : "") + DoubleToString(d.positionPL, 2),
                     d.positionPL >= 0 ? m_cfg.clrBullish : m_cfg.clrBearish);
      }
      else
      {
         UpdateLabel("val_position", "No Position", m_cfg.clrTextMuted);
         UpdateLabel("val_sltp",    "- / -");
         UpdateLabel("val_tradepl", "-");
      }
      UpdateLabel("val_trades",
         IntegerToString(d.tradesToday) + " (" + IntegerToString(d.winsToday) + "W / " +
         IntegerToString(d.lossesToday) + "L)");

      UpdateLabel("val_riskmode", d.riskModeName);
      UpdateLabel("val_nextlot",  DoubleToString(d.nextLotSize, 2));
      UpdateLabel("val_martlvl",  d.martingaleLevel > 0 ? "Level " + IntegerToString(d.martingaleLevel) : "Off",
                  d.martingaleLevel > 0 ? m_cfg.clrWarning : m_cfg.clrTextMuted);

      if(d.showPropFirm)
      {
         UpdateLabel("val_propdaily",
            DoubleToString(d.dailyDDPct, 1) + "% / " + DoubleToString(d.dailyDDLimit, 1) + "%");
         UpdateProgressBar("pbar_daily",
            (d.dailyDDLimit > 0) ? d.dailyDDPct / d.dailyDDLimit * 100.0 : 0, pbarWidth,
            d.dailyDDPct > d.dailyDDLimit * 0.8 ? m_cfg.clrBearish : m_cfg.clrBullish);
         UpdateLabel("val_proptotal",
            DoubleToString(d.totalDDPct, 1) + "% / " + DoubleToString(d.totalDDLimit, 1) + "%");
         UpdateProgressBar("pbar_total",
            (d.totalDDLimit > 0) ? d.totalDDPct / d.totalDDLimit * 100.0 : 0, pbarWidth,
            d.totalDDPct > d.totalDDLimit * 0.8 ? m_cfg.clrBearish : m_cfg.clrBullish);
      }

      UpdateLabel("val_clock", d.currentTimeStr + " (" + m_cfg.timeModeLabel + ")");

      if(d.nextNewsEvent != "" && d.newsMinutesAway >= 0)
         UpdateLabel("val_news", d.nextNewsEvent + " (" + IntegerToString(d.newsMinutesAway) + "m)",
                     d.newsMinutesAway < 30 ? m_cfg.clrWarning : m_cfg.clrTextSecondary);
      else
         UpdateLabel("val_news", "None nearby", m_cfg.clrTextMuted);

      if(d.nextScanSec > 0)
         UpdateLabel("val_nextscan", IntegerToString(d.nextScanSec) + "s", m_cfg.clrTextPrimary);
      else
         UpdateLabel("val_nextscan", "Ready", m_cfg.clrBullish);

      UpdateLabel("foottime", "Updated: " + TimeToString(d.lastUpdate, TIME_SECONDS));
      UpdateLabel("footconn", CharToString(0x25CF), d.connected ? m_cfg.clrBullish : m_cfg.clrBearish);

      ChartRedraw();
   }

   void ToggleMinimize()
   {
      m_minimized = !m_minimized;
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, m_prefix) != 0) continue;
         if(StringFind(name, "header") >= 0 || StringFind(name, "title") >= 0 ||
            StringFind(name, "btn_") >= 0 || StringFind(name, "ver") >= 0 ||
            StringFind(name, "timemode") >= 0)
            continue;
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, m_minimized ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS);
      }
      ChartRedraw();
   }

   bool OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
   {
      if(id == CHARTEVENT_OBJECT_CLICK)
      {
         if(sparam == m_prefix + "btn_min")   { ToggleMinimize(); return true; }
         if(sparam == m_prefix + "btn_close") { Destroy(); return true; }
         return false;
      }

      if(id == CHARTEVENT_MOUSE_MOVE)
      {
         int mouseX = (int)lparam;
         int mouseY = (int)dparam;
         bool leftPressed = (StringToInteger(sparam) & 1) != 0;

         if(leftPressed && !m_dragging && IsOverHeader(mouseX, mouseY))
         {
            m_dragging = true;
            m_dragStartMouseX = mouseX;
            m_dragStartMouseY = mouseY;
            m_dragStartPanelX = m_baseX;
            m_dragStartPanelY = m_baseY;
            return true;
         }
         if(m_dragging && leftPressed)
         {
            int dx = mouseX - m_dragStartMouseX;
            int dy = mouseY - m_dragStartMouseY;
            if(dx != 0 || dy != 0)
            {
               MoveAllObjects(dx, dy);
               m_dragStartMouseX = mouseX;
               m_dragStartMouseY = mouseY;
               ChartRedraw();
            }
            return true;
         }
         if(m_dragging && !leftPressed)
         {
            m_dragging = false;
            return true;
         }
      }
      return false;
   }

   void Destroy()
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
      ObjectsDeleteAll(0, m_prefix);
      ChartRedraw();
   }

   bool IsMinimized() const { return m_minimized; }
   bool IsDragging()  const { return m_dragging; }
};

//=============================================================================
//  GLOBAL MODULE INSTANCES
//=============================================================================
CFilters       g_filters;
CRiskManager   g_risk;
CAPIHandler    g_api;
CTradeManager  g_trade;
CAIVPanel      g_panel;

//=============================================================================
//  GLOBAL STATE
//=============================================================================
datetime g_lastAPICallTime = 0;
string   g_blockReason     = "";
bool     g_fridayClosed    = false;
string   g_lastDecision    = "NONE";
int      g_lastConfidence  = 0;
string   g_lastReason      = "Waiting for signal...";
bool     g_moneyFilterTriggered = false;
string   g_moneyFilterReason    = "";

double g_propDailyDDPct    = 0;
double g_propTotalDDPct    = 0;
double g_propDailyProfitMoney  = 0;
double g_propChallengeTargetMoney = 0;

//=============================================================================
//  HELPERS — Account Mode / Money Filter
//=============================================================================
double ResolveInitialBalance()
{
   if(InpPropInitBalance > 0) return InpPropInitBalance;
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

double PropValueAsPercent(double rawValue)
{
   if(rawValue <= 0) return 0;
   if(InpPropRiskUnit == PROP_UNIT_PERCENT) return rawValue;
   double initBal = ResolveInitialBalance();
   if(initBal <= 0) return 0;
   return (rawValue / initBal) * 100.0;
}

double PropValueAsMoney(double rawValue)
{
   if(rawValue <= 0) return 0;
   if(InpPropRiskUnit == PROP_UNIT_MONEY) return rawValue;
   double initBal = ResolveInitialBalance();
   if(initBal <= 0) return 0;
   return (rawValue / 100.0) * initBal;
}

void RecomputePropFirmValues()
{
   g_propDailyDDPct    = PropValueAsPercent(InpPropDailyLossLimit);
   g_propTotalDDPct    = PropValueAsPercent(InpPropMaxTotalDrawdown);
   g_propDailyProfitMoney  = PropValueAsMoney(InpPropDailyProfitTarget);
   g_propChallengeTargetMoney = PropValueAsMoney(InpPropChallengeTarget);
}

bool IsMoneyFilterTriggered(string &reason)
{
   if(InpAccountType != ACCOUNT_STANDARD) return false;
   if(!InpUseMoneyFilter)                 return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpEquityProfitTarget > 0 && equity >= InpEquityProfitTarget)
   {
      reason = "MONEY FILTER — PROFIT TARGET REACHED";
      return true;
   }
   if(InpEquityLossLimit > 0 && equity <= InpEquityLossLimit)
   {
      reason = "MONEY FILTER — LOSS LIMIT REACHED";
      return true;
   }
   return false;
}

//=============================================================================
//  OnInit
//=============================================================================
int OnInit()
{
   // API key only required in AI Hybrid mode
   if(InpTradingMode == MODE_AI_HYBRID && InpAPIKey == "")
   {
      Alert(AIV_EA_NAME + ": AI Hybrid mode selected but API Key is empty! "
                          "Either enter an API key, or switch Trading Mode to Indicators Only.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpAccountType == ACCOUNT_STANDARD && InpUseMoneyFilter)
   {
      if(InpEquityProfitTarget > 0 && InpEquityLossLimit > 0 &&
         InpEquityProfitTarget <= InpEquityLossLimit)
      {
         Alert(AIV_EA_NAME + ": Money Filter invalid — Profit Target must be greater than Loss Limit.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }
   if(InpAccountType == ACCOUNT_PROP_FIRM || InpAccountType == ACCOUNT_FUNDED)
   {
      if(InpPropDailyLossLimit <= 0 || InpPropMaxTotalDrawdown <= 0)
      {
         Alert(AIV_EA_NAME + ": Prop Firm mode requires Daily Loss Limit and Max Total Drawdown > 0.");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   // Validate indicator inputs
   if(InpADXPeriod <= 0)
   {
      Alert(AIV_EA_NAME + ": ADX Period must be greater than 0.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpJawPeriod <= 0 || InpTeethPeriod <= 0 || InpLipsPeriod <= 0)
   {
      Alert(AIV_EA_NAME + ": Alligator periods must be greater than 0.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpATRTrailPeriod <= 0)
   {
      Alert(AIV_EA_NAME + ": ATR Trail Period must be greater than 0.");
      return INIT_PARAMETERS_INCORRECT;
   }

   RecomputePropFirmValues();

   if(!g_filters.Init(_Symbol, InpMagicNumber, TF,
                      InpADXPeriod, InpADXMinLevel,
                      InpJawPeriod, InpJawShift,
                      InpTeethPeriod, InpTeethShift,
                      InpLipsPeriod, InpLipsShift))
      return INIT_FAILED;

   g_risk.Init(_Symbol, InpMagicNumber, InpPropInitBalance);

   // Only initialize API handler when AI Hybrid mode is active
   if(InpTradingMode == MODE_AI_HYBRID)
   {
      if(!g_api.Init(_Symbol, InpMagicNumber, InpAPIKey, InpProviderOverride,
                     InpAPITimeoutSec, InpChartWidth, InpChartHeight, InpChartBars,
                     TF))
      {
         PrintFormat("[Main] API init warning: %s", g_api.GetLastStatus());
      }
   }
   else
   {
      PrintFormat("[Main] Indicators-Only mode active — AI provider not used");
   }

   if(!g_trade.Init(_Symbol, InpMagicNumber, InpUseTrailingStop, InpTrailMode, InpATRTrailPeriod))
      return INIT_FAILED;

   if(InpShowPanel)
   {
      bool showProp = (InpAccountType == ACCOUNT_PROP_FIRM || InpAccountType == ACCOUNT_FUNDED);

      PanelConfig cfg;
      cfg.panelWidth      = InpPanelWidth;
      cfg.fontSizeData    = InpFontSizeData;
      cfg.fontSizeHeader  = InpFontSizeHeader;
      cfg.fontSizeTitle   = InpFontSizeTitle;
      cfg.fontData        = InpFontData;
      cfg.fontHeader      = InpFontHeader;
      cfg.clrBackground   = InpClrBackground;
      cfg.clrHeader       = InpClrHeader;
      cfg.clrSectionHdr   = InpClrSectionHeader;
      cfg.clrAccent       = InpClrAccent;
      cfg.clrBullish      = InpClrBullish;
      cfg.clrBearish      = InpClrBearish;
      cfg.clrWarning      = InpClrWarning;
      cfg.clrTextPrimary  = InpClrTextPrimary;
      cfg.clrTextSecondary= InpClrTextSecondary;
      cfg.clrTextMuted    = InpClrTextMuted;
      cfg.clrBorder       = InpClrBorder;
      cfg.clrProgressBg   = C'30,35,55';
      cfg.clrInactiveBg   = C'30,25,15';
      cfg.clrInactiveHdr  = C'35,28,10';
      cfg.clrInactiveBorder = C'60,50,20';
      cfg.clrInactiveText = C'160,140,80';

      if(InpTimeMode == TIME_GMT_OFFSET)
      {
         string sign = (InpGMTOffsetHours >= 0) ? "+" : "";
         cfg.timeModeLabel = "GMT" + sign + IntegerToString(InpGMTOffsetHours);
         if(InpGMTOffsetMins != 0)
            cfg.timeModeLabel += ":" + IntegerToString(MathAbs(InpGMTOffsetMins));
      }
      else
         cfg.timeModeLabel = "Broker";

      g_panel.Create(InpPanelCorner, InpPanelX, InpPanelY, showProp, cfg);
   }

   EventSetTimer(1);

   PrintFormat("[%s v%s] Initialized on %s | Magic=%d | Mode=%s | Provider=%s | TF=%s | Stack: %s/%s/%s | Scan=%ds",
               AIV_EA_NAME, AIV_VERSION,
               _Symbol, InpMagicNumber,
               (InpTradingMode == MODE_AI_HYBRID) ? "AI Hybrid" : "Indicators Only",
               (InpTradingMode == MODE_AI_HYBRID) ? EnumToString(g_api.GetProvider()) : "N/A",
               TFName(TF),
               g_api.GetTFEntryName(),
               g_api.GetTFMidName(),
               g_api.GetTFHighName(),
               InpScanIntervalSec);

   return INIT_SUCCEEDED;
}

//=============================================================================
//  OnDeinit
//=============================================================================
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_filters.Deinit();
   g_trade.Deinit();
   g_panel.Destroy();
   PrintFormat("[%s] Deinitialized. Reason=%d", AIV_EA_NAME, reason);
}

//=============================================================================
//  OnTick
//=============================================================================
void OnTick()
{
   RecomputePropFirmValues();

   g_risk.UpdateDrawdown(InpAccountType, g_propDailyDDPct, g_propTotalDDPct,
                         g_propDailyProfitMoney, InpPropUseTrailingDrawdown, InpMartingaleResetDaily);

   g_trade.ManageTrailingStop(InpUseTrailingStop, InpTrailMode, InpTrailDistance,
                              InpBreakevenPlus, InpATRTrailMultiplier, InpPipMultiplier);
   g_trade.ManagePartialClose(InpUsePartialClose, InpPartialClose1_Pct, InpPartialClose1_RR,
                              InpPartialClose2_Pct, InpPartialClose2_RR);

   if(g_filters.IsFridayCloseTime(InpCloseFriday, InpFridayCloseTime,
                                   InpTimeMode, InpGMTOffsetHours, InpGMTOffsetMins) && !g_fridayClosed)
   {
      g_trade.CloseAllPositions(InpAlertOnTrade, InpPushNotification, InpEmailAlert);
      g_fridayClosed = true;
      g_blockReason  = "Friday close — positions closed";
      return;
   }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week != 5) g_fridayClosed = false;

   if(InpAccountType == ACCOUNT_STANDARD)
   {
      if(IsMoneyFilterTriggered(g_moneyFilterReason))
      {
         if(!g_moneyFilterTriggered)
         {
            g_moneyFilterTriggered = true;
            if(g_trade.HasOpenPosition())
               g_trade.CloseAllPositions(InpAlertOnTrade, InpPushNotification, InpEmailAlert);
         }
         g_blockReason = g_moneyFilterReason;
         return;
      }
      g_moneyFilterTriggered = false;
   }

   string ddBlock = "";
   if(!g_risk.IsTradingAllowed(ddBlock, InpAccountType))
   {
      if(g_trade.HasOpenPosition())
         g_trade.CloseAllPositions(InpAlertOnTrade, InpPushNotification, InpEmailAlert);
      g_blockReason = ddBlock;
      return;
   }

   g_blockReason = "";

   if(!g_filters.IsTradingDay(InpTradeMonday, InpTradeTuesday, InpTradeWednesday,
                               InpTradeThursday, InpTradeFriday,
                               InpTimeMode, InpGMTOffsetHours, InpGMTOffsetMins))
   {
      g_blockReason = "Day filter: disabled today";
      return;
   }

   if(!g_filters.IsInTradingTime(InpTradingStartTime, InpTradingEndTime,
                                  InpTimeMode, InpGMTOffsetHours, InpGMTOffsetMins))
   {
      g_blockReason = "Time filter: outside hours";
      return;
   }

   if(g_filters.IsNewsBlocking(InpUseNewsFilter, InpNewsMinutesBefore,
                                InpNewsMinutesAfter, InpNewsHighImpactOnly))
   {
      g_blockReason = "News: " + g_filters.GetNextNewsName();
      return;
   }

   if(!g_filters.IsSpreadOK(InpMaxSpread))
   {
      g_blockReason = StringFormat("Spread %d > %d", g_filters.GetCurrentSpread(), InpMaxSpread);
      return;
   }

   if(g_trade.HasOpenPosition())
      return;

   PreFilterState preFilter = g_filters.EvaluatePreFilters();
   if(preFilter.signal == SIGNAL_NONE)
      return;

   //═══════════════════════════════════════════════════════════════════════════
   //  TRADING MODE BRANCH
   //  - INDICATORS_ONLY: trade immediately on pre-filter signal (no API call)
   //  - AI_HYBRID:       call AI to confirm direction before trading
   //═══════════════════════════════════════════════════════════════════════════

   AIAnalysisResult tradeSignal;
   tradeSignal.Reset();

   if(InpTradingMode == MODE_INDICATORS_ONLY)
   {
      // Build a synthetic signal from pre-filter (no AI call)
      tradeSignal.direction = (preFilter.signal == SIGNAL_BULLISH) ? AI_DIR_BUY : AI_DIR_SELL;
      tradeSignal.confidence = (int)MathMin(100, MathMax(50, preFilter.adxValue * 2));
      tradeSignal.slPrice = 0;   // SL/TP modes that need price (AI_DECIDES, AI_SL_RR) will fall back to fixed
      tradeSignal.tpPrice = 0;
      tradeSignal.reason = StringFormat("Indicators-Only: %s | ADX=%.1f",
         (preFilter.signal == SIGNAL_BULLISH) ? "BULL" : "BEAR", preFilter.adxValue);
      tradeSignal.isValid = true;

      g_lastDecision   = (tradeSignal.direction == AI_DIR_BUY) ? "BUY" : "SELL";
      g_lastConfidence = tradeSignal.confidence;
      g_lastReason     = tradeSignal.reason;

      // In indicators-only mode, force a fixed SL/TP mode if user picked an AI-dependent one
      // (caller of GetSLDistancePoints / ExecuteTrade will use the user's mode setting,
      //  but with slPrice=0 the AI_DECIDES path falls back to fixed pips automatically.)
   }
   else
   {
      // ─── AI HYBRID MODE ───
      int elapsed = (int)(TimeCurrent() - g_lastAPICallTime);
      if(g_lastAPICallTime > 0 && elapsed < InpScanIntervalSec)
         return;

      if(!g_api.AnalyzeCharts(preFilter.signal, tradeSignal,
                              InpSLTPMode, InpFixedSL_Pips, InpFixedTP_Pips,
                              InpFixedSL_Points, InpFixedTP_Points, InpRiskReward))
      {
         g_lastDecision = "ERROR";
         g_lastReason   = g_api.GetLastStatus();
         return;
      }

      g_lastAPICallTime = TimeCurrent();
      g_lastDecision   = (tradeSignal.direction == AI_DIR_BUY) ? "BUY" :
                         (tradeSignal.direction == AI_DIR_SELL) ? "SELL" : "NONE";
      g_lastConfidence = tradeSignal.confidence;
      g_lastReason     = tradeSignal.reason;

      if(tradeSignal.direction == AI_DIR_NONE) return;
      if(tradeSignal.confidence < InpMinConfidence) return;

      // Pre-filter direction must match AI direction
      bool match = false;
      if(preFilter.signal == SIGNAL_BULLISH && tradeSignal.direction == AI_DIR_BUY)  match = true;
      if(preFilter.signal == SIGNAL_BEARISH && tradeSignal.direction == AI_DIR_SELL) match = true;
      if(!match) return;
   }

   // ─── COMMON TRADE EXECUTION (both modes) ───
   double slDistPts = g_trade.GetSLDistancePoints(tradeSignal, InpSLTPMode,
                                                   InpFixedSL_Pips, InpFixedSL_Points, InpPipMultiplier);
   double lotSize = g_risk.CalculateLotSize(slDistPts,
                     InpRiskMode, InpFixedLot, InpRiskPercent, InpRiskMoney,
                     InpMinLot, InpMaxLot,
                     InpUseMartingale, InpMartingaleMultiplier, InpMartingaleMaxLevel,
                     InpMartingaleLotStep,
                     InpAccountType, g_propDailyDDPct);

   g_trade.ExecuteTrade(tradeSignal, lotSize,
                        InpSLTPMode, InpFixedSL_Pips, InpFixedTP_Pips,
                        InpFixedSL_Points, InpFixedTP_Points, InpRiskReward,
                        InpPipMultiplier, InpMinSL_Pips, InpMaxSL_Pips,
                        InpAlertOnTrade, InpPushNotification, InpEmailAlert);
}

//=============================================================================
//  OnTimer
//=============================================================================
void OnTimer()
{
   if(!InpShowPanel) return;

   g_risk.RecalcSessionStats();

   PanelData pd;

   pd.balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   pd.equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   pd.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   pd.dailyPL    = g_risk.GetDrawdownTracker().dailyPL;
   pd.drawdownPct= g_risk.GetTotalDDPercent(InpPropUseTrailingDrawdown);

   pd.bid          = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   pd.ask          = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   pd.spreadPoints = g_filters.GetCurrentSpread();

   pd.provider      = g_api.GetProvider();
   pd.modelName     = (InpTradingMode == MODE_AI_HYBRID) ? g_api.GetModelName() : "Indicators-Only Mode";
   pd.apiCallsToday = g_api.GetCallsToday();
   pd.aiStatus      = (g_blockReason != "") ? g_blockReason :
                      (InpTradingMode == MODE_INDICATORS_ONLY) ? "ADX + Alligator only (no API)" :
                      g_api.GetLastStatus();
   pd.lastDecision  = g_lastDecision;
   pd.lastConfidence= g_lastConfidence;
   pd.lastReason    = g_lastReason;

   pd.tfEntryName = g_api.GetTFEntryName();
   pd.tfMidName   = g_api.GetTFMidName();
   pd.tfHighName  = g_api.GetTFHighName();

   string posType = "";
   double posLots=0, posSL=0, posTP=0, posPL=0;
   pd.hasPosition = g_trade.GetPositionInfo(posType, posLots, posSL, posTP, posPL);
   pd.positionType = posType; pd.positionLots = posLots;
   pd.positionSL = posSL; pd.positionTP = posTP; pd.positionPL = posPL;

   SessionStats stats = g_risk.GetSessionStats();
   pd.tradesToday = g_risk.CountTradesToday();
   pd.winsToday   = stats.wins;
   pd.lossesToday = stats.losses;

   pd.riskModeName    = EnumToString(InpRiskMode);
   pd.nextLotSize     = InpFixedLot;
   pd.martingaleLevel = g_risk.GetMartingaleLevel();

   pd.showPropFirm = (InpAccountType == ACCOUNT_PROP_FIRM || InpAccountType == ACCOUNT_FUNDED);
   pd.dailyDDPct   = g_risk.GetDailyDDPercent();
   pd.dailyDDLimit = g_propDailyDDPct;
   pd.totalDDPct   = g_risk.GetTotalDDPercent(InpPropUseTrailingDrawdown);
   pd.totalDDLimit = g_propTotalDDPct;

   pd.nextNewsEvent   = g_filters.GetNextNewsName();
   pd.newsMinutesAway = g_filters.GetNewsMinutesAway();

   pd.eaActive    = (g_blockReason == "");
   pd.blockReason = g_blockReason;

   pd.currentTimeStr = g_filters.GetCurrentTimeString(InpTimeMode, InpGMTOffsetHours, InpGMTOffsetMins);

   if(g_lastAPICallTime > 0)
   {
      int elapsed = (int)(TimeCurrent() - g_lastAPICallTime);
      pd.nextScanSec = MathMax(0, InpScanIntervalSec - elapsed);
   }
   else
      pd.nextScanSec = 0;

   pd.lastUpdate = TimeCurrent();
   pd.connected  = TerminalInfoInteger(TERMINAL_CONNECTED) != 0;

   g_panel.Update(pd);
}

//=============================================================================
//  OnChartEvent
//=============================================================================
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(InpShowPanel && g_panel.OnChartEvent(id, lparam, dparam, sparam))
      return;

   if(id == CHARTEVENT_KEYDOWN)
   {
      string keyChar = "";
      if(lparam >= 32 && lparam <= 126)
         keyChar = CharToString((uchar)lparam);

      StringToUpper(keyChar);
      string emergKey = InpEmergencyKey;
      StringToUpper(emergKey);

      if(keyChar == emergKey)
      {
         int result = MessageBox(
            "EMERGENCY: Close ALL positions for " + _Symbol + " (Magic " +
            IntegerToString(InpMagicNumber) + ")?",
            AIV_EA_NAME + " — Emergency", MB_YESNO | MB_ICONWARNING);

         if(result == IDYES)
         {
            g_trade.CloseAllPositions(InpAlertOnTrade, InpPushNotification, InpEmailAlert);
            PrintFormat("[EMERGENCY] All positions closed by user");
         }
      }
   }
}

//+------------------------------------------------------------------+
//  END OF PRIME QUANTUM AI v3.20 (Single-File Build)
//+------------------------------------------------------------------+
