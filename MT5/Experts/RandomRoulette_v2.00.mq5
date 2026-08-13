//+------------------------------------------------------------------+
//|                                      Random Roulette EA v2.00    |
//|                        Copyright 2024-2026, Lybeedo              |
//|                        https://t.me/Lybeedo                      |
//|                        License: Free - Use at your own risk      |
//|                                                                  |
//|  Based on: EA Random Roulette v1.2SP (MT4) by Cuancux Algo      |
//|  Ported to MQL5 with CTrade + Position API                      |
//|  Fixed: server flooding, trailing SL direction, GoodTime check,  |
//|         anti-flood throttle                                      |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024-2026, Lybeedo"
#property link        "https://t.me/lybeedo"
#property description "Random Roulette EA v2.00 (MT5)"
#property version     "2.00"
#property strict
#property description "Entry signal and lot multiplier is random, Mr. Martingale will take care of it"
#property description "Set your favourite Lot Multiplier by adjust SpinnerStart and SpinnerEnd Value"
#property description "Randomized Lot Multiplier is 1.0 to 4.0"
#property description " "
#property description "DISCLAIMER: Use it at your own risk"

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum  enumONFF {
   eTurnOn,    //Enabled
   eTurnOff,   //Disabled
};
enum enumLotType{
   eFixLot,    //Fix LotSize
   eMulti,     //Multiplier
};

enum EngineType {
    FollowTrend,    // Kosong adalah Isi
    CounterTrend,   // Isi adalah Kosong
};

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input string f0                    = "READ THE DESCRIPTION";  //READ ME
input string f1                    = "Entry signal and lot multiplier is random, Mr. Martingale will take care of it"; // Instruction
input string f2 = "_____"; //-----> Random Roulette EA v2.00 MT5 <-----
input double      LotSize      = 0.01;     //Lot Size
enumLotType LotType            = eMulti;   //Add Lot Mode
input int SpinnerStart = 2; // Spinner Start (1 to 7)
input int SpinnerEnd = 7;   // Spinner End (1 to 7)
input string SP = "1.0x ; 1.3x ; 1.7x ; 2.0x ; 2.5x ; 3.0x ; 4.0x"; //-----> Spinner 1~7 <-----
input int         MaxLayer     = 15;          //Maximal Layer
enumONFF IN_IsBySignal  = eTurnOff;     //Averaging by Signal
input int         PipDistance  = 150;          //Pip Distance
input int         TakeProfit   = 50; //Take Profit
input  enumONFF TrailingStop = eTurnOn;  //Enable Trailing
input  int        TrailingStart= 40; //Trailing Start
input  int        TrailingStep = 20;  //Trailing Step

input string f3 = "_____";   //-----> Engine <-----
input EngineType Engine = FollowTrend; // Select Engine

input string f4 = "_____";   //-----> Misc. <-----

input int         Slippage        = 3;  //Slippage (points)
input int         MagicNumber     = 234; //Magic Number
input bool        Use_Time_Filter = false; // Use Time Filter
input string      Time_Start      = "07:00";// Time Start
input string      Time_End        = "23:50";// Time End
input bool        TradeOnMonday = true; //Trade On Monday
input bool        TradeOnTuesday = true; //Trade On Tuesday
input bool        TradeOnWednesday = true; //Trade On Wednesday
input bool        TradeOnThursday = true; //Trade On Thursday
input bool        TradeOnFriday = true; //Trade On Friday
input bool        TradeOnSaturday = true; //Trade On Saturday
input bool        TradeOnSunday = true; //Trade On Sunday
input string      Remarks = "Random Roulette EA v2.00 | Suggestion & Feedback https://t.me/Lybeedo";

//--- Anti-flood: minimum seconds between PositionModify calls
#define MODIFY_THROTTLE_SEC 3

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade trade;

int      GDigit         = 0;
double   GPoint         = 0.0;
string   TF;
datetime gLastModifyTime = 0;
datetime gLastTrailingTime = 0;

//+------------------------------------------------------------------+
//| Position tracker classes (MT5 equivalent of cOrder/cOrderTPSL)   |
//+------------------------------------------------------------------+
class cPosition{
   protected:
      int    tOrders, type;
      double harga, hargaTA, hargaTB;
      double lot, lotTKcl, lotTBsr;
      datetime opTime;
      bool   status;
   public:
      cPosition(void);
      void updatePosition(int posType, double price, double lotSize, datetime time, bool isInc, bool isUpdate);
      void updateStatus(bool isUpdate){ status=isUpdate;};
      int getTtlOrders(){ return (tOrders); }
      double getHargaTA(){ return (NormalizeDouble(hargaTA, GDigit));}
      double getHargaTB(){ return (NormalizeDouble(hargaTB, GDigit));}
      bool getStatus(){ return(status); }
};

cPosition::cPosition(void){
   tOrders = 0;
   type = -1;
   harga = hargaTA = hargaTB = 0.0;
   lot = lotTKcl = lotTBsr = 0.0;
   opTime = 0;
   status = false;
};

void cPosition::updatePosition(int posType, double price, double lotSize, datetime time, bool isInc, bool isUpdate){
   if (isInc) tOrders++;
   status = isUpdate;
   type = posType;
   if (opTime < time){
      harga = price;
      lot   = lotSize;
      opTime = time;
   }
   if (price > hargaTA) hargaTA = price;
   if (price < hargaTB || hargaTB == 0.0) hargaTB = price;
   if (lotSize > lotTBsr) lotTBsr = lotSize;
   if (lotSize < lotTKcl || lotTKcl == 0) lotTKcl = lotSize;
};

class cPositionTPSL{
   private:
      double tLot, tValue;
      bool   isUpdate;
   public:
      cPositionTPSL(){
         tLot = tValue = 0.0;
         isUpdate = false;
      }
      void updateData(double opPrice, double lotSize, bool st);
      double getBEP();
      bool getStatus(){ return(isUpdate); }
      void updateStatus(bool st=false){ isUpdate = st; }
};

void cPositionTPSL::updateData(double opPrice, double lotSize, bool st){
   tLot  += lotSize;
   tValue += opPrice * lotSize;
   if (!isUpdate) isUpdate = st;
}

double cPositionTPSL::getBEP(){
   return(NormalizeDouble(tValue/tLot, GDigit));
}

//+------------------------------------------------------------------+
//| Helper: count positions for this EA                               |
//+------------------------------------------------------------------+
int CountPositions()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY || posType == POSITION_TYPE_SELL)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
   MathSrand(GetTickCount());

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Display label
   string Labels = "https://t.me/Lybeedo";
   ObjectCreate(0, "L2", OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, "L2", OBJPROP_TEXT, Labels);
   ObjectSetInteger(0, "L2", OBJPROP_FONTSIZE, 15);
   ObjectSetString(0, "L2", OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, "L2", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "L2", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, "L2", OBJPROP_XDISTANCE, 5);
   ObjectSetInteger(0, "L2", OBJPROP_YDISTANCE, 6);

   if(TakeProfit < 0)
   {
      Alert("Invalid input parameter");
      return (INIT_PARAMETERS_INCORRECT);
   }

   if (SpinnerStart < 1 || SpinnerEnd > 7 || SpinnerStart > SpinnerEnd) {
      Print("Error: SpinnerStart must be >= 1, SpinnerEnd must be <= 7, and SpinnerStart <= SpinnerEnd.");
      return (INIT_PARAMETERS_INCORRECT);
   }

   GDigit = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   GPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(GDigit % 2 == 1) GPoint *= 10;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0);
   Print("Expert Advisor deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   DisplayPanel();

   if (!IsTradingAllowed()) return;
   if (!GoodTime()) return;

   bool isNewCS = NewCandle();

   // Cari Signal buy/sell
   int signal = -1;
   string Random = "";
   if (isNewCS) {
      signal = GetSignal(Random);
   }

   cPosition buy, sell;
   ManagePositions(signal, buy, sell, Random);

   //--- Anti-flood: only run TP/SL and trailing when there are orders, and throttle
   bool hasOrders = (CountPositions() > 0);
   datetime now = TimeCurrent();

   if (hasOrders && (now - gLastModifyTime >= MODIFY_THROTTLE_SEC))
   {
      SetTPSLMarti();
   }

   if (hasOrders && TrailingStop == eTurnOn && (now - gLastTrailingTime >= MODIFY_THROTTLE_SEC))
   {
      SetTrailingStop(buy, sell);
      gLastTrailingTime = now;
   }

   if(Period() == PERIOD_M1)  TF = "M1";
   else if(Period() == PERIOD_M5)  TF = "M5";
   else if(Period() == PERIOD_M15) TF = "M15";
   else if(Period() == PERIOD_M30) TF = "M30";
   else if(Period() == PERIOD_H1)  TF = "H1";
   else if(Period() == PERIOD_H4)  TF = "H4";
   else if(Period() == PERIOD_D1)  TF = "D1";
   else if(Period() == PERIOD_W1)  TF = "W1";
   else if(Period() == PERIOD_MN1) TF = "MN";
}

//+------------------------------------------------------------------+
//| GetSignal                                                        |
//+------------------------------------------------------------------+
int GetSignal(string &Random) {
    int signal = -1;
    int Direction = MathRand() % 2;

    switch (Engine) {
        case FollowTrend:
            if (Direction == 0) {
                signal = 0; // BUY
                Random = "0";
            } else {
                signal = 1; // SELL
                Random = "1";
            }
            break;

        case CounterTrend:
            if (Direction == 1) {
                signal = 0; // BUY
                Random = "1";
            } else {
                signal = 1; // SELL
                Random = "0";
            }
            break;
    }
    return signal;
}

//+------------------------------------------------------------------+
//| ManagePositions                                                  |
//+------------------------------------------------------------------+
void ManagePositions(int orderType, cPosition &buy, cPosition &sell, string Random) {
    // Scan open positions
    for(int i = PositionsTotal()-1; i >= 0; i--){
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        long posType = PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double posLot = PositionGetDouble(POSITION_VOLUME);
        datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
        double posTP = PositionGetDouble(POSITION_TP);
        bool status = (posTP == 0.0);

        if(posType == POSITION_TYPE_BUY)
            buy.updatePosition(0, openPrice, posLot, posTime, true, status);
        if(posType == POSITION_TYPE_SELL)
            sell.updatePosition(1, openPrice, posLot, posTime, true, status);
    }

    // Open initial order
    double vol = GetLotSize(0);
    double hargaOP = 0.0;
    bool isAllowOP = false;

    if (orderType == 0 && buy.getTtlOrders() == 0) {
        hargaOP = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        isAllowOP = true;
    } else if (orderType == 1 && sell.getTtlOrders() == 0) {
        hargaOP = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        isAllowOP = true;
    }

    if (isAllowOP && GoodTime()) {
        if (!CekMargin(orderType, vol)) {
            Print("Not sufficient margin, order not successfully executed");
        } else {
            bool result = false;
            if(orderType == 0)
                result = trade.Buy(vol, _Symbol, 0, 0, 0, "Roulette #"+ TF +" Sp"+IntegerToString(SpinnerStart)+"~"+IntegerToString(SpinnerEnd)+" @Lybeedo");
            else
                result = trade.Sell(vol, _Symbol, 0, 0, 0, "Roulette #"+ TF +" Sp"+IntegerToString(SpinnerStart)+"~"+IntegerToString(SpinnerEnd)+" @Lybeedo");

            if(result)
                Print("Order successfully sent");
            else
                Print("Order failed. Error: ", GetLastError());
        }
    }

    // MARTINGALE / AVERAGING
    double hargaOpen = 0.0;
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // BUY averaging
    if (buy.getTtlOrders() > 0 && buy.getTtlOrders() < MaxLayer && (orderType == 0 || IN_IsBySignal == eTurnOff) && GoodTime()) {
        hargaOpen = buy.getHargaTB() - (PipDistance * GPoint);
        if (hargaOpen >= ask) {
            vol = GetLotSize(buy.getTtlOrders());
            if (!CekMargin(0, vol))
                Print("Not sufficient margin, order not successfully executed");
            else
                trade.Buy(vol, _Symbol, 0, 0, 0, "Roulette #"+ TF +" Sp"+IntegerToString(SpinnerStart)+"~"+IntegerToString(SpinnerEnd)+" @Lybeedo");
        }
    }

    // SELL averaging — FIX: proper parentheses and GoodTime() check
    if (sell.getTtlOrders() > 0 && sell.getTtlOrders() < MaxLayer && (orderType == 1 || IN_IsBySignal == eTurnOff) && GoodTime()) {
        hargaOpen = sell.getHargaTA() + (PipDistance * GPoint);
        if (hargaOpen <= bid) {
            vol = GetLotSize(sell.getTtlOrders());
            if (!CekMargin(1, vol))
                Print("Not sufficient margin, order not successfully executed");
            else
                trade.Sell(vol, _Symbol, 0, 0, 0, "Roulette #"+ TF +" Sp"+IntegerToString(SpinnerStart)+"~"+IntegerToString(SpinnerEnd)+" @Lybeedo");
        }
    }
}

//+------------------------------------------------------------------+
//| SetTrailingStop — MT5                                            |
//+------------------------------------------------------------------+
void SetTrailingStop(cPosition &buy, cPosition &sell){
   // FIX: Only trail when exactly 1 order exists
   if (TrailingStop != eTurnOn) return;
   if (buy.getTtlOrders() != 1 && sell.getTtlOrders() != 1) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);

      // FIX: BUY trailing — use Bid for SL calculation
      if(posType == POSITION_TYPE_BUY && buy.getTtlOrders() == 1){
         if((bid - (TrailingStart * GPoint)) >= openPrice
            && (bid - ((TrailingStart+TrailingStep)*GPoint)) > currentSL)
         {
            double sl = NormalizeDouble(bid - (TrailingStart * GPoint), GDigit);
            if(sl > 0 && sl != currentSL){
               if(trade.PositionModify(ticket, sl, PositionGetDouble(POSITION_TP))){
                  Print("Trailing BUY updated ",ticket," SL=",sl);
                  gLastModifyTime = TimeCurrent();
               }
            }
         }
      }
      // FIX: SELL trailing — use Ask for SL calculation
      if(posType == POSITION_TYPE_SELL && sell.getTtlOrders() == 1){
         if((ask + (TrailingStart * GPoint)) <= openPrice
            && ((ask + ((TrailingStart+TrailingStep)*GPoint)) < currentSL || currentSL == 0))
         {
            double sl = NormalizeDouble(ask + (TrailingStart * GPoint), GDigit);
            if(sl > 0 && sl != currentSL){
               if(trade.PositionModify(ticket, sl, PositionGetDouble(POSITION_TP))){
                  Print("Trailing SELL updated ",ticket," SL=",sl);
                  gLastModifyTime = TimeCurrent();
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SetTPSLMarti — MT5                                              |
//+------------------------------------------------------------------+
void SetTPSLMarti(){
   cPositionTPSL BUY, SELL;

   for(int i = PositionsTotal()-1; i >= 0; i--){
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posLot = PositionGetDouble(POSITION_VOLUME);
      double posTP = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
         BUY.updateData(openPrice, posLot, (posTP == 0));
      if(posType == POSITION_TYPE_SELL)
         SELL.updateData(openPrice, posLot, (posTP == 0));
   }

   if (BUY.getStatus() || SELL.getStatus()){
      double tpBuy = 0.0, tpSell = 0.0;

      if (BUY.getStatus()) tpBuy  = BUY.getBEP() + (TakeProfit * GPoint);
      if (SELL.getStatus()) tpSell = SELL.getBEP() - (TakeProfit * GPoint);

      for(int i = PositionsTotal()-1; i >= 0; i--){
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

         long posType = PositionGetInteger(POSITION_TYPE);
         double currentTP = PositionGetDouble(POSITION_TP);

         if(posType == POSITION_TYPE_BUY && BUY.getStatus()){
            if(tpBuy > 0 && tpBuy != currentTP){
               if(trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpBuy)){
                  Print("TP set BUY ",ticket," TP=",tpBuy);
                  gLastModifyTime = TimeCurrent();
               } else {
                  Print("TP modify failed BUY ",ticket);
               }
            }
         }
         if(posType == POSITION_TYPE_SELL && SELL.getStatus()){
            if(tpSell > 0 && tpSell != currentTP){
               if(trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpSell)){
                  Print("TP set SELL ",ticket," TP=",tpSell);
                  gLastModifyTime = TimeCurrent();
               } else {
                  Print("TP modify failed SELL ",ticket);
               }
            }
         }
      }

      BUY.updateStatus();
      SELL.updateStatus();
   }
}

//+------------------------------------------------------------------+
//| CalculateMultiplier                                              |
//+------------------------------------------------------------------+
double CalculateMultiplier(int spinnerStart, int spinnerEnd) {
    if (spinnerStart < 1 || spinnerEnd > 7 || spinnerStart > spinnerEnd) {
        Print("Invalid spinner range: Start=", spinnerStart, ", End=", spinnerEnd);
        return 1.0;
    }

    int randomize = spinnerStart + (MathRand() % (spinnerEnd - spinnerStart + 1));

    if (randomize == 1) return 1.3;
    else if (randomize == 2) return 1.7;
    else if (randomize == 3) return 2.0;
    else if (randomize == 4) return 2.5;
    else if (randomize == 5) return 3.0;
    else if (randomize == 6) return 4.0;
    else return 1.1;
}

//+------------------------------------------------------------------+
//| GetLotSize — MT5                                                |
//+------------------------------------------------------------------+
double GetLotSize(int tOrderType) {
    double lot = 0.0;
    double dynamicMultiplier = CalculateMultiplier(SpinnerStart, SpinnerEnd);

    double lastLot = LotSize;
    for(int i = PositionsTotal()-1; i >= 0; i--){
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        lastLot = PositionGetDouble(POSITION_VOLUME);
        break;
    }

    if (tOrderType == 0) {
        lot = LotSize;
    } else {
        if (LotType == eMulti)
            lot = lastLot * dynamicMultiplier;
        else
            lot = lastLot;
    }

    double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    lot = MathRound(lot / lotStep) * lotStep;
    lot = MathMin(MathMax(lot, minLot), maxLot);
    lot = NormalizeDouble(lot, 2);

    return lot;
}

//+------------------------------------------------------------------+
//| CekMargin — MT5                                                |
//+------------------------------------------------------------------+
bool CekMargin(int orderType, double lot){
   double margin;
   ENUM_ORDER_TYPE ot = (orderType == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(ot, _Symbol, lot, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin)){
      return false;
   }
   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) < margin){
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| NewCandle                                                        |
//+------------------------------------------------------------------+
bool NewCandle(){
   static datetime opTime = TimeCurrent();
   if(iTime(_Symbol, PERIOD_CURRENT, 0) > opTime){
      opTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| GoodTime                                                         |
//+------------------------------------------------------------------+
bool GoodTime()
{
   int hs1 = (int)StringToInteger(StringSubstr(Time_Start, 0, 2));
   int ms1 = (int)StringToInteger(StringSubstr(Time_Start, 3, 2));
   int he1 = (int)StringToInteger(StringSubstr(Time_End, 0, 2));
   int me1 = (int)StringToInteger(StringSubstr(Time_End, 3, 2));

   if(!Use_Time_Filter)
      return true;

   MqlDateTime dt;
   TimeCurrent(dt);
   int curH = dt.hour;
   int curM = dt.min;

   if(hs1 < he1){
      if((curH > hs1 || (curH == hs1 && curM >= ms1)) && (curH < he1 || (curH == he1 && curM <= me1)))
         return true;
   }
   if(hs1 > he1){
      if((curH > hs1 || (curH == hs1 && curM >= ms1)) || (curH < he1 || (curH == he1 && curM <= me1)))
         return true;
   }
   if(hs1 == he1){
      if(curH == hs1 && curM >= ms1 && curM <= me1)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| IsTradingAllowed                                                |
//+------------------------------------------------------------------+
bool IsTradingAllowed() {
    MqlDateTime dt;
    TimeCurrent(dt);
    int currentDay = dt.day_of_week;

    switch (currentDay) {
        case 0: return TradeOnSunday;
        case 1: return TradeOnMonday;
        case 2: return TradeOnTuesday;
        case 3: return TradeOnWednesday;
        case 4: return TradeOnThursday;
        case 5: return TradeOnFriday;
        case 6: return TradeOnSaturday;
        default: return false;
    }
}

//+------------------------------------------------------------------+
//| GetLast4DigitsOfAccount                                          |
//+------------------------------------------------------------------+
string GetLast4DigitsOfAccount() {
    string fullAccountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
    if (StringLen(fullAccountNumber) >= 4) {
        return StringSubstr(fullAccountNumber, StringLen(fullAccountNumber) - 4, 4);
    }
    return fullAccountNumber;
}

//+------------------------------------------------------------------+
//| DisplayPanel                                                     |
//+------------------------------------------------------------------+
void DisplayPanel()
{
   string ActiveHours = "";
   if(Use_Time_Filter) ActiveHours = Time_Start + " to " + Time_End;
   else ActiveHours = "Non Stop Trading";

   string TrailingStopL = (TrailingStop == eTurnOff) ? "Disabled" : "Enabled";

   string SignalStr;
   MathSrand(GetTickCount());
   int Direction = MathRand() % 2;
   SignalStr = (Direction == 0) ? "Buy" : "Sell";

   string DisplayText =
      "                                   || >>> Random Roulette EA v2.00 (MT5) - https://t.me/Lybeedo <<<"
      + "\n"
      + "                                   || Account ID _____ " + GetLast4DigitsOfAccount()
      + "\n"
      + "                                   || Setting ID ______ " + IntegerToString(MagicNumber)
      + "\n"
      + "                                   || Max Layer ______ " + IntegerToString(CountPositions()) + " / " + IntegerToString(MaxLayer)
      + "\n"
      + "                                   || Spinner ________ " + IntegerToString(SpinnerStart) + " ~ " + IntegerToString(SpinnerEnd)
      + "\n"
      + "                                   || Random ________ " + SignalStr
      + "\n"
      + "                                   || Trailing System _ " + TrailingStopL
      + "\n"
      + "                                   || Trailing ________ " + IntegerToString(TrailingStart) + " / " + IntegerToString(TrailingStep) + " pts"
      + "\n"
      + "                                   || Current Time ___ " + TimeToString(TimeCurrent())
      + "\n"
      + "                                   || Active Time ____ " + ActiveHours
      + "\n"
      + "                                   || Copyright 2024-2026 - https://t.me/Lybeedo"
      ;

   Comment(DisplayText);
}
//+------------------------------------------------------------------+
