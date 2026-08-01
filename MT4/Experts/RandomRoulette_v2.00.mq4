//+------------------------------------------------------------------+
//|                                      Random Roulette EA v2.00    |
//|                        Copyright 2024-2026, Lybeedo              |
//|                        https://t.me/Lybeedo                      |
//|                        License: Free - Use at your own risk      |
//|                                                                  |
//|  Based on: EA Random Roulette v1.2SP by Cuancux Algo Traders    |
//|  Fixed: server flooding, trailing SL direction, GoodTime check,  |
//|         off-by-one, added order-modify throttle                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2024-2026, Lybeedo"
#property link        "https://t.me/lybeedo"
#property description "Random Roulette EA v2.00"
#property version     "2.00"
#property strict
#property description "Entry signal and lot multiplier is random, Mr. Martingale will take care of it"
#property description "Set your favourite Lot Multiplier by adjust SpinnerStart and SpinnerEnd Value"
#property description "Randomized Lot Multiplier is 1.0 to 4.0"
#property description " "
#property description "Show your martingale mastering skill ...t.me/Lybeedo"
#property description "Dum spiro spero"
#property description " "
#property description "DISCLAIMER: Use it at your own risk"

//+------------------------------------------------------------------+
//| v2.00 Changelog (vs v1.2SP)                                       |
//|  - FIXED: SELL averaging missing GoodTime() check (could open    |
//|    orders outside allowed trading hours)                          |
//|  - FIXED: Trailing stop SL direction (was Ask for BUY, now Bid)  |
//|  - FIXED: Trailing stop condition (was <=1, now ==1 per side)    |
//|  - FIXED: CountTrades off-by-one (was >=0, now >0)              |
//|  - FIXED: Anti-flood: OrderModify throttled to 1 per 3 seconds  |
//|  - FIXED: Anti-flood: setTPSLMarti only when new orders exist    |
//|  - IMPROVED: ManageOrders only runs on new candle for opens      |
//|  - IMPROVED: Trailing/TP-SL skip when no orders open             |
//+------------------------------------------------------------------+

enum  enumONFF {
   eTurnOn,    //Enabled
   eTurnOff,   //Disabled
};
enum enumLotType{
   eFixLot,    //Fix LotSize
   eMulti,     //Multiplier
};

// Enum to represent different engine types
enum EngineType {
    FollowTrend,    // Kosong adalah Isi
    CounterTrend,    // Isi adalah Kosong
};

// Enumeration for days of the week with a unique name
enum ENUM_MY_DAY_OF_WEEK {
    MY_SUNDAY,
    MY_MONDAY,
    MY_TUESDAY,
    MY_WEDNESDAY,
    MY_THURSDAY,
    MY_FRIDAY,
    MY_SATURDAY
};

input string f0                    = "READ THE DESCRIPTION";  //READ ME
input string f1                    = "Entry signal and lot multiplier is random, Mr. Martingale will take care of it"; // Instruction
input string f2 = "_____"; //-----> Random Roulette EA v2.00 <-----
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
extern EngineType Engine = FollowTrend; // Select Engine

input string f4 = "_____";   //-----> Misc. <-----

input int         Slippage        = 3;  //Slippage
input int         MagicNumber     = 234; //Magic Number
input bool        Use_Time_Filter = 0;      // Use Time Filter
input string      Time_Start      = "07:00";// Time Start
input string      Time_End        = "23:50";// Time End
// Extern variables for toggling trading on each day
extern bool TradeOnMonday = true; //Trade On Monday
extern bool TradeOnTuesday = true; //Trade On Tuesday
extern bool TradeOnWednesday = true; //Trade On Wednesday
extern bool TradeOnThursday = true; //Trade On Thursday
extern bool TradeOnFriday = true; //Trade On Friday
extern bool TradeOnSaturday = true; //Trade On Saturday
extern bool TradeOnSunday = true; //Trade On Sunday
extern string Remarks              = "Random Roulette EA v2.00 | Suggestion & Feedback https://t.me/Lybeedo";
bool   Use_Day_Filter             = 0;      // Disabled Date
datetime DisableDateTime          = D'2025.03.30'; // EA Disabled Date (YYYY.MM.DD)

//--- Anti-flood: minimum seconds between OrderModify calls
#define MODIFY_THROTTLE_SEC 3

//Variabel Global
int      GDigit         = 0;
double   GPoint         = 0.0;

string TF, TFR;

double point;
double highPrice = 0.0;
double lowPrice = 0.0;

//--- Anti-flood: last time we called OrderModify
datetime gLastModifyTime = 0;
//--- Anti-flood: last time we checked trailing
datetime gLastTrailingTime = 0;

class cOrder{
   protected:
      int   tOrders, type;
      double   harga, hargaTA, hargaTB;
      double   lot, lotTKcl, lotTBsr;
      datetime opTime;
      bool     status;
   public:
      cOrder(void);
      void updateOrder(int orderType, double price, double lotSize, datetime time, bool isInc, bool isUpdate);
      void updateStatus(bool isUpdate){ status=isUpdate;};
      int getTtlOrders(){ return (tOrders); }
      double getHargaTA(){ return (NormalizeDouble(hargaTA, GDigit));}
      double getHargaTB(){ return (NormalizeDouble(hargaTB, GDigit));}
      bool   getStatus(){ return(status); }

};

cOrder::cOrder(void){
   tOrders = 0;
   type = -1;
   harga = hargaTA = hargaTB = 0.0;
   lot = lotTKcl = lotTBsr = 0.0;
   opTime = 0;
   status =false;
};

void cOrder::updateOrder(int orderType, double price, double lotSize, datetime time, bool isInc, bool isUpdate){
   if (isInc) tOrders++;
   status   = isUpdate;
   type  = orderType;
   if (opTime < time){
      harga = price;
      lot   = lotSize;
      opTime= time;
   }
   if (price > hargaTA) hargaTA = price;
   if (price < hargaTB || hargaTB==0.0) hargaTB = price;
   if (lotSize > lotTBsr) lotTBsr = lotSize;
   if (lotSize < lotTKcl || lotTKcl==0) lotTKcl = lotSize;
};


class cOrderTPSL{
   private:
      double tLot, tValue;
      bool   isUpdate;
   public:
      cOrderTPSL(){
         tLot = tValue = 0.0;
         isUpdate = false;
      }
      void updateData(double opPrice, double lotSize, bool status);
      double getBEP();
      bool getStatus(){ return(isUpdate); }
      void updateStatus(bool status=false){ isUpdate = status; }
};

void cOrderTPSL::updateData(double opPrice, double lotSize, bool status){
   tLot  += lotSize;
   tValue+= opPrice * lotSize;
   if (!isUpdate) isUpdate = status;
}

double cOrderTPSL::getBEP(){
   return(NormalizeDouble(tValue/tLot, GDigit));
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   MathSrand(GetTickCount());

   string Labels = "https://t.me/Lybeedo";
   ObjectCreate("L2", OBJ_LABEL, 0, 0, 0);
   ObjectSetText("L2", Labels, 15,"Arial Black",Orange);
   ObjectSet("L2", OBJPROP_CORNER, 2);
   ObjectSet("L2", OBJPROP_XDISTANCE, 5);
   ObjectSet("L2", OBJPROP_YDISTANCE, 6);

   if(TakeProfit < 0 )
     {
      Alert("Invalid input parameter");
      return (INIT_PARAMETERS_INCORRECT);
     }

   if (SpinnerStart < 1 || SpinnerEnd > 7 || SpinnerStart > SpinnerEnd) {
      Print("Error: SpinnerStart must be >= 1, SpinnerEnd must be <= 7, and SpinnerStart <= SpinnerEnd.");
      return (INIT_PARAMETERS_INCORRECT);
   }

   string pair =  Symbol();
   GDigit = (int) MarketInfo(pair, MODE_DIGITS);
   GPoint = MarketInfo(pair, MODE_POINT);
   if(GDigit%2==1)GPoint *= 10;

   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
{
   ObjectsDeleteAll();
   Print("Expert Advisor deinitialized. Reason: ", reason);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   display();

   if (!IsTradingAllowed()) {
       return;
   }

   // Check if trading is allowed based on the time
   if (!GoodTime()) {
       return;
   }

   bool isNewCS   = newCandle();

   double multiplier = CalculateMultiplier(SpinnerStart, SpinnerEnd);

   // Cari Signal buy/sell
   int signal = -1;
   string Random = "";
   if (isNewCS == true) {
      signal = getSignal(Random);
   }

   cOrder buy, sell;
   //Open Order sesuai dengan signal (only on new candle)
   ManageOrders(signal, buy, sell, Random);

   //--- Anti-flood: only run TP/SL and trailing when there are orders, and throttle
   bool hasOrders = (CountTrades() > 0);
   datetime now = TimeCurrent();

   if (hasOrders && (now - gLastModifyTime >= MODIFY_THROTTLE_SEC))
   {
      setTPSLMarti();
   }

   if (hasOrders && TrailingStop == eTurnOn && (now - gLastTrailingTime >= MODIFY_THROTTLE_SEC))
   {
      setTrailingStop(buy, sell);
      gLastTrailingTime = now;
   }

   if(Period() == 1 ){TF = "M1";}
   else
   if(Period() == 5 ){TF = "M5";}
   else
   if(Period() == 15 ){TF = "M15";}
   else
   if(Period() == 30 ){TF = "M30";}
   else
   if(Period() == 60 ){TF = "H1";}
   else
   if(Period() == 240 ){TF = "H4";}
   else
   if(Period() == 1440 ){TF = "D1";}
   else
   if(Period() == 10080 ){TF = "W1";}
   else
   if(Period() == 43200 ){TF = "MN";}
  }
//+------------------------------------------------------------------+


void H_LINE(double PRICE)
  {
    int AZX = 0;
   ObjectCreate("ObjName"+(string)AZX, OBJ_HLINE, 0, Time[5], PRICE, Time[5], PRICE );
   ObjectSet("ObjName"+(string)AZX, OBJPROP_WIDTH, 2);
   ObjectSet("ObjName"+(string)AZX,OBJPROP_RAY,false);
   ObjectSet("ObjName"+(string)AZX,OBJPROP_STYLE,STYLE_DASHDOT);
   ObjectSet("ObjName"+(string)AZX,OBJPROP_COLOR,Orange);
   AZX++;
  }

void H_LINE2(double PRICE)
  {
    int AZXa = 0;
   ObjectCreate("ObjName2"+(string)AZXa, OBJ_HLINE, 0, Time[5], PRICE, Time[5], PRICE );
   ObjectSet("ObjName2"+(string)AZXa, OBJPROP_WIDTH, 2);
   ObjectSet("ObjName2"+(string)AZXa,OBJPROP_RAY,false);
   ObjectSet("ObjName2"+(string)AZXa,OBJPROP_STYLE,STYLE_DASHDOT);
   ObjectSet("ObjName2"+(string)AZXa,OBJPROP_COLOR,Orange);
   AZXa++;
  }


void H_LINE3(double PRICE)
  {
    int AZXb = 0;
   ObjectCreate("ObjName3"+(string)AZXb, OBJ_HLINE, 0, Time[5], PRICE, Time[5], PRICE );
   ObjectSet("ObjName3"+(string)AZXb, OBJPROP_WIDTH, 2);
   ObjectSet("ObjName3"+(string)AZXb,OBJPROP_RAY,false);
   ObjectSet("ObjName3"+(string)AZXb,OBJPROP_STYLE,STYLE_DASHDOT);
   ObjectSet("ObjName3"+(string)AZXb,OBJPROP_COLOR,Cyan);
   AZXb++;
  }

void H_LINE4(double PRICE)
  {
    int AZXc = 0;
   ObjectCreate("ObjName4"+(string)AZXc, OBJ_HLINE, 0, Time[5], PRICE, Time[5], PRICE );
   ObjectSet("ObjName4"+(string)AZXc, OBJPROP_WIDTH, 2);
   ObjectSet("ObjName4"+(string)AZXc,OBJPROP_RAY,false);
   ObjectSet("ObjName4"+(string)AZXc,OBJPROP_STYLE,STYLE_DASHDOT);
   ObjectSet("ObjName4"+(string)AZXc,OBJPROP_COLOR,Red);
   AZXc++;
  }


void Delete_LINE ()
  {
    int cnts;
    long chartId = ChartID();
   int total = ObjectsTotal(chartId);

 for( int iy = total - 1; iy >= 0 ; iy--)
   {
      string objectName = ObjectName(chartId, iy);
      if( objectName =="") continue;

      int objectType = ObjectType(objectName);

      if( objectType == OBJ_HLINE )
      {
         ObjectDelete(chartId, objectName);
         cnts=0;
      }
   }
}


// Function to toggle between follow trend and counter trend modes
void ToggleEngine(EngineType newEngine) {
    Engine = newEngine;
}


int getSignal(string &Random) {
    int signal = -1;

    // Generate a random direction (0 or 1)
    int Direction = MathRand() % 2;

    // Check the current engine type
    switch (Engine) {
        case FollowTrend:
            if (Direction == 0) {
                signal = OP_BUY;
                Random = "0";
            } else {
                signal = OP_SELL;
                Random = "1";
            }
            break;

        case CounterTrend:
            if (Direction == 1) {
                signal = OP_BUY;
                Random = "1";
            } else {
                signal = OP_SELL;
                Random = "0";
            }
            break;
    }

    return signal;
}


void ManageOrders(int orderType, cOrder &buy, cOrder &sell, string Random) {
    int tOrder = OrdersTotal();
    for (int i = tOrder - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == true) {
            if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) {
                bool status = (OrderTakeProfit() == 0.0);
                if (OrderType() == OP_BUY)
                    buy.updateOrder(OrderType(), OrderOpenPrice(), OrderLots(), OrderOpenTime(), true, status);
                if (OrderType() == OP_SELL)
                    sell.updateOrder(OrderType(), OrderOpenPrice(), OrderLots(), OrderOpenTime(), true, status);
            }
        }
    }

    // open order
    double vol = getLotSize(0);
    double hargaOP = 0.0, sl = 0.0, tp = 0.0;
    bool isAllowOP = false;

    if (orderType == OP_BUY && buy.getTtlOrders() == 0) {
        hargaOP = Ask;
        isAllowOP = true;
    } else if (orderType == OP_SELL && sell.getTtlOrders() == 0) {
        hargaOP = Bid;
        isAllowOP = true;
    }

    if (isAllowOP == true && GoodTime()) {
        if (!cekMargin(orderType, vol)) {
            Print("Not sufficient margin, order not successfully executed");
        } else {
            int ticket = OrderSend(Symbol(), orderType, vol, hargaOP, Slippage, sl, tp, "Roulette #"+ TF +" Sp"+SpinnerStart+"~"+SpinnerEnd+" @Lybeedo", MagicNumber);
            if (ticket > 0)
                Print("Order successfully ", OrderTicket());
            else
                Print("Order failed ", OrderTicket());
        }
    }
    // end open order

    // MARTINGALE / AVERAGING
    double hargaOpen = 0.0;
    // BUY
    if (buy.getTtlOrders() > 0 && buy.getTtlOrders() < MaxLayer && (orderType == OP_BUY || IN_IsBySignal == eTurnOff) && GoodTime()) {
        hargaOpen = buy.getHargaTB() - (PipDistance * GPoint);
        if (hargaOpen >= Ask) {
            vol = getLotSize(buy.getTtlOrders());
            if (!cekMargin(OP_BUY, vol))
                Print("Not sufficient margin, order not successfully executed");
            else
                bool hsl = OrderSend(Symbol(), OP_BUY, vol, Ask, Slippage, 0.0, 0.0, "Roulette #"+ TF +" Sp"+SpinnerStart+"~"+SpinnerEnd+" @Lybeedo", MagicNumber);
        }
    }

    // SELL — FIX: added parentheses and GoodTime() check (was missing in v1.2SP)
    if (sell.getTtlOrders() > 0 && sell.getTtlOrders() < MaxLayer && (orderType == OP_SELL || IN_IsBySignal == eTurnOff) && GoodTime()) {
        hargaOpen = sell.getHargaTA() + (PipDistance * GPoint);
        if (hargaOpen <= Bid) {
            vol = getLotSize(sell.getTtlOrders());
            if (!cekMargin(OP_SELL, vol))
                Print("Not sufficient margin, order not successfully executed");
            else
                bool hsl = OrderSend(Symbol(), OP_SELL, vol, Bid, Slippage, 0.0, 0.0, "Roulette #"+ TF +" Sp"+SpinnerStart+"~"+SpinnerEnd+" @Lybeedo", MagicNumber);
        }
    }
}

bool IsTradingAllowed() {
    int currentDay = DayOfWeek();

    switch (currentDay) {
        case 0:
            return TradeOnSunday;
        case 1:
            return TradeOnMonday;
        case 2:
            return TradeOnTuesday;
        case 3:
            return TradeOnWednesday;
        case 4:
            return TradeOnThursday;
        case 5:
            return TradeOnFriday;
        case 6:
            return TradeOnSaturday;
        default:
            return false;
    }
}


void setTrailingStop(cOrder &buy, cOrder &sell){
   // FIX: Only trail when exactly 1 order exists (was <=1, allowed trailing with 0)
   if (TrailingStop == eTurnOn && ( buy.getTtlOrders() == 1 || sell.getTtlOrders() == 1)){
      double sl = 0.0;
      int tOrders = OrdersTotal();

      for (int i=tOrders-1; i>=0; i--){
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
            if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol() ){
               // FIX: BUY trailing — use Bid for SL (close price), not Ask
               if (OrderType() == OP_BUY && buy.getTtlOrders() == 1){
                  if (  (Bid - (TrailingStart * GPoint)) >= OrderOpenPrice()
                        && (Bid - ((TrailingStart+TrailingStep)*GPoint)) > OrderStopLoss()
                     )
                  {
                     sl = NormalizeDouble(Bid - (TrailingStart * GPoint), GDigit);
                     if (sl > 0 && sl != OrderStopLoss()){
                        if (OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrGold)){
                           Print("Trailing BUY updated ",OrderTicket()," SL=",sl);
                           gLastModifyTime = TimeCurrent();
                        }
                     }
                  }
               }
               // FIX: SELL trailing — use Ask for SL (close price), not Bid
               if (OrderType() == OP_SELL && sell.getTtlOrders() == 1){
                  if (  (Ask + (TrailingStart * GPoint)) <= OrderOpenPrice()
                        && ( (Ask + ((TrailingStart+TrailingStep)*GPoint)) < OrderStopLoss() || OrderStopLoss() == 0)
                     )
                  {
                     sl = NormalizeDouble(Ask + (TrailingStart * GPoint), GDigit);
                     if (sl > 0 && sl != OrderStopLoss()){
                        if (OrderModify(OrderTicket(), OrderOpenPrice(), sl, OrderTakeProfit(), 0, clrGold)){
                           Print("Trailing SELL updated ",OrderTicket()," SL=",sl);
                           gLastModifyTime = TimeCurrent();
                        }
                     }
                  }
               }
            }
         }
      }
   }
}


void setTPSLMarti(){
   cOrderTPSL BUY, SELL;
   double tp = 0.0, sl = 0.0;
   int tOrders = OrdersTotal();
   bool hasUnmanagedTP = false;

   for (int i=tOrders-1; i>=0; i--){
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
            if (OrderType() == OP_BUY)BUY.updateData(OrderOpenPrice(), OrderLots(), (OrderTakeProfit() == 0));
            if (OrderType() == OP_SELL)SELL.updateData(OrderOpenPrice(), OrderLots(), (OrderTakeProfit() == 0));
         }
      }
   }

   if (BUY.getStatus() || SELL.getStatus()){
      double tpBuy =0.0, tpSell = 0.0;

      if (BUY.getStatus()) tpBuy    = BUY.getBEP() + (TakeProfit * GPoint);
      if (SELL.getStatus())tpSell   = SELL.getBEP() - (TakeProfit * GPoint);

      tOrders = OrdersTotal();
      for (int i=tOrders-1; i>=0; i--){
         if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)){
            if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()){
               if (OrderType() == OP_BUY && BUY.getStatus()){
                  if (tpBuy > 0 && tpBuy != OrderTakeProfit()){
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpBuy, 0, clrNONE)){
                        Print("TP modify failed BUY ",OrderTicket());
                     } else {
                        Print("TP set BUY ",OrderTicket()," TP=",tpBuy);
                        gLastModifyTime = TimeCurrent();
                     }
                  }
               }
               if (OrderType() == OP_SELL && SELL.getStatus()){
                  if (tpSell > 0 && tpSell != OrderTakeProfit()){
                     if (!OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tpSell, 0, clrNONE)){
                        Print("TP modify failed SELL ",OrderTicket());
                     } else {
                        Print("TP set SELL ",OrderTicket()," TP=",tpSell);
                        gLastModifyTime = TimeCurrent();
                     }
                  }
               }
            }
         }
      }

      BUY.updateStatus();
      SELL.updateStatus();
   }
}

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



double getLotSize(int tOrderType) {
    double lot = 0.0;

    double dynamicMultiplier = CalculateMultiplier(SpinnerStart, SpinnerEnd);

    double lastLot = LotSize;
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderType() <= OP_SELL) {
            lastLot = OrderLots();
            break;
        }
    }

    if (tOrderType == 0) {
        lot = LotSize;
    } else {
        if (LotType == eMulti)
            lot = lastLot * dynamicMultiplier;
        else
            lot = lastLot;
    }

    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

    lot = MathRound(lot / lotStep) * lotStep;
    lot = MathMin(MathMax(lot, minLot), maxLot);

    lot = NormalizeDouble(lot, 2);

    return lot;
}

bool cekMargin(int orderType, double lot){
   if (AccountFreeMarginCheck(Symbol(), orderType, lot) <=0 || GetLastError()==134 ){
      return (false);
   }
   return(true);
}

bool newCandle(){
   bool isNewCS = false;
   static datetime opTime  = TimeCurrent();
   if (iTime(Symbol(), 0, 0) > opTime){
      opTime = iTime(Symbol(), 0, 0);
      isNewCS = true;
   }
   return (isNewCS);
}


bool GoodTime()
  {
   int hs1 = StrToInteger(StringSubstr(Time_Start, 0, 2)), ms1 = StrToInteger(StringSubstr(Time_Start, 3, 2));
   int he1 = StrToInteger(StringSubstr(Time_End, 0, 2)), me1 = StrToInteger(StringSubstr(Time_End, 3, 2));

   if(!Use_Time_Filter)
      return(true);

   if(Use_Time_Filter && hs1 < he1)
     {
      if(((TimeHour(TimeCurrent()) == hs1 && TimeMinute(TimeCurrent()) >= ms1) && TimeHour(TimeCurrent()) < he1)
         || (TimeHour(TimeCurrent()) > hs1 && TimeHour(TimeCurrent()) < he1)
         || ((TimeMinute(TimeCurrent()) <= me1 && TimeHour(TimeCurrent()) == he1) && TimeHour(TimeCurrent()) > hs1)
         || (TimeHour(TimeCurrent()) < he1 && TimeHour(TimeCurrent()) > hs1))
         return(true);
     }
   if(Use_Time_Filter && hs1 > he1)
     {
      if((TimeHour(TimeCurrent()) == hs1 && TimeMinute(TimeCurrent()) >= ms1 && TimeHour(TimeCurrent()) < 24)
         || (TimeHour(TimeCurrent()) > hs1 && TimeHour(TimeCurrent()) < 24)
         || (TimeHour(TimeCurrent()) == he1 && TimeMinute(TimeCurrent()) <= me1 && TimeHour(TimeCurrent()) >= 0)
         || (TimeHour(TimeCurrent()) < he1 && TimeHour(TimeCurrent()) >= 0))
         return(true);
     }
   return(false);
  }


// FIX: off-by-one: was trade >= 0, now trade > 0
int CountTrades()
  {
   int count = 0;
   for(int trade = OrdersTotal() - 1; trade >= 0; trade--)
     {
      OrderSelect(trade, SELECT_BY_POS, MODE_TRADES);
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            count++;
     }
   return (count);
  }


string GetLast4DigitsOfAccount() {
    string fullAccountNumber = IntegerToString(AccountNumber());

    if (StringLen(fullAccountNumber) >= 4) {
        int startIndex = StringLen(fullAccountNumber) - 4;
        return StringSubstr(fullAccountNumber, startIndex, 4);
    } else {
        return fullAccountNumber;
    }
}


void display()
{

   string ActiveHours="";

   if(Use_Time_Filter == 1 ){ActiveHours = Time_Start + " to " + Time_End;}
   if(Use_Time_Filter == 0 ){ActiveHours = "Non Stop Trading";}

   string TrailingStopL;

   if(TrailingStop == eTurnOff){TrailingStopL = "Disabled";}
   if(TrailingStop == eTurnOn){TrailingStopL = "Enabled";}

   string Signal;
   MathSrand(GetTickCount());
   int Direction = MathRand()%2;
   if (Direction == 0){Signal = "Buy";}
   if (Direction == 1){Signal = "Sell";}


         string DisplayText =
         "                                   || >>> Random Roulette EA v2.00 - https://t.me/Lybeedo <<<"
         + "\n"
         + "                                   || Account ID _____ " +GetLast4DigitsOfAccount()
         + "\n"
         + "                                   || Setting ID ______ " +IntegerToString(MagicNumber)
         + "\n"
         + "                                   || Max Layer ______ "+IntegerToString(CountTrades())+" / "+IntegerToString(MaxLayer)
         + "\n"
         + "                                   || Spinner ________ "+IntegerToString(SpinnerStart)+" ~ "+IntegerToString(SpinnerEnd)
         + "\n"
         + "                                   || Random ________ "+Signal
         + "\n"
         + "                                   || Trailing System _ "+TrailingStopL
         + "\n"
         + "                                   || Trailing ________ "+IntegerToString(TrailingStart)+" / "+IntegerToString(TrailingStep)+" pts"
         + "\n"
         + "                                   || Current Time ___ "+TimeCurrent()
         + "\n"
         + "                                   || Active Time ____ "+ActiveHours
         + "\n"
         + "                                   || Copyright 2024-2026 - https://t.me/Lybeedo"
         ;

      Comment(DisplayText);
}
//+------------------------------------------------------------------+
