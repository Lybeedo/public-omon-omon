//+------------------------------------------------------------------+
//|                                                  SR_Zones.mqh   |
//|                          Cuancux Algo Traders • Paulus Is        |
//+------------------------------------------------------------------+
#ifndef SR_ZONES_MQH
#define SR_ZONES_MQH

#include <Object.mqh>
#include <Arrays\List.mqh>

//+------------------------------------------------------------------+
//|  Zone direction enum                                             |
//+------------------------------------------------------------------+
enum ENUM_ZONE_TYPE
  {
   ZONE_NONE    = 0,
   ZONE_BUY     = 1,   // demand zone — bullish reactions
   ZONE_SELL    = 2    // supply zone  — bearish reactions
  };

//+------------------------------------------------------------------+
//|  Zone validity state                                             |
//+------------------------------------------------------------------+
enum ENUM_ZONE_STATE
  {
   ZONE_ACTIVE     = 0,  // price still within / touching zone
   ZONE_VALIDATED  = 1,  // price reacted and confirming candle appeared
   ZONE_INVALIDATED= 2   // price broke zone, invalidation triggered
  };

//+------------------------------------------------------------------+
//|  Zone structure                                                  |
//+------------------------------------------------------------------+
struct SZone
  {
   string            name;           // rectangle object name
   ENUM_ZONE_TYPE    type;           // BUY or SELL
   ENUM_ZONE_STATE   state;          // active / validated / invalidated
   double            priceHigh;      // top of zone (rectangle price high)
   double            priceLow;       // bottom of zone (rectangle price low)
   datetime          creationTime;   // when zone was created
   int               touchCount;     // number of times price touched zone
   datetime          lastTouchTime;  // last touch
   int               barsSinceTouch; // bars since last touch
   double            entryPrice;     // price when signal triggered
   double            stopLoss;       // calculated SL price
   double            takeProfit;     // calculated TP price
   bool              entryTriggered; // entry already fired for this zone
  };

//+------------------------------------------------------------------+
//|  SR_Zones — manages all S/R zones on chart                      |
//+------------------------------------------------------------------+
class CSR_Zones
  {
private:
   SZone             m_zones[];
   int               m_zoneCount;
   string            m_buyPrefix;
   string            m_sellPrefix;
   int               m_invalidationBars;
   double            m_touchTolPips;

public:
                     CSR_Zones(void);
                    ~CSR_Zones(void);

   void              Configure(string buyPrefix, string sellPrefix,
                               int invalidationBars, double touchTolPips);

   void              Scan(void);                       // find all zone rectangles
   int               ZoneCount(void)    const         { return m_zoneCount;   }
   SZone*            GetZone(int idx);

   bool              FindZoneByName(string name, SZone &zone);
   ENUM_ZONE_TYPE    DetectZoneType(string objName);

   void              UpdateTouches(void);             // update touch count / bar age
   void              CheckInvalidation(int invalidationBars);
   void              InvalidateZone(int idx);

   double            GetZoneHigh(int idx)    const;
   double            GetZoneLow(int idx)     const;
   ENUM_ZONE_TYPE    GetZoneType(int idx)    const;
   ENUM_ZONE_STATE   GetZoneState(int idx)   const;

   string            StateToString(ENUM_ZONE_STATE s);
   void              LogAllZones(int logLevel);
  };

//+------------------------------------------------------------------+
CSR_Zones::CSR_Zones(void) : m_zoneCount(0), m_invalidationBars(3),
                              m_touchTolPips(10.0)
  {
   m_buyPrefix  = "SR_BuyZone";
   m_sellPrefix = "SR_SellZone";
   ArrayResize(m_zones, 0);
  }

//+------------------------------------------------------------------+
CSR_Zones::~CSR_Zones(void)
  {
  }

//+------------------------------------------------------------------+
void CSR_Zones::Configure(string buyPrefix, string sellPrefix,
                          int invalidationBars, double touchTolPips)
  {
   m_buyPrefix        = buyPrefix;
   m_sellPrefix        = sellPrefix;
   m_invalidationBars  = invalidationBars;
   m_touchTolPips     = touchTolPips;
  }

//+------------------------------------------------------------------+
//|  Scan chart for all zone rectangles and populate m_zones[]       |
//+------------------------------------------------------------------+
void CSR_Zones::Scan(void)
  {
   m_zoneCount = 0;
   ArrayResize(m_zones, 64);

   // Scan all chart objects
   int totalObjects = ObjectsTotal(0);  // chart only, 0=subwindow
   for(int i = 0; i < totalObjects; i++)
     {
      string objName = ObjectName(0, i);
      ENUM_ZONE_TYPE zt = DetectZoneType(objName);
      if(zt == ZONE_NONE) continue;

      SZone z;
      z.name           = objName;
      z.type           = zt;
      z.state          = ZONE_ACTIVE;
      z.priceHigh      = ObjectGetDouble(0, objName, OBJPROP_PRICE, 1);
      z.priceLow       = ObjectGetDouble(0, objName, OBJPROP_PRICE, 0);
      z.creationTime   = (datetime)ObjectGetInteger(0, objName, OBJPROP_CREATETIME);
      z.touchCount     = 0;
      z.lastTouchTime  = 0;
      z.barsSinceTouch = 0;
      z.entryPrice     = 0;
      z.stopLoss       = 0;
      z.takeProfit     = 0;
      z.entryTriggered = false;

      m_zones[m_zoneCount++] = z;
     }
  }

//+------------------------------------------------------------------+
//|  Determine zone type from object name prefix                     |
//+------------------------------------------------------------------+
ENUM_ZONE_TYPE CSR_Zones::DetectZoneType(string objName)
  {
   if(StringFind(objName, m_buyPrefix) == 0)  return ZONE_BUY;
   if(StringFind(objName, m_sellPrefix) == 0) return ZONE_SELL;
   return ZONE_NONE;
  }

//+------------------------------------------------------------------+
//|  Find zone by name (return false if not found)                   |
//+------------------------------------------------------------------+
bool CSR_Zones::FindZoneByName(string name, SZone &zone)
  {
   for(int i = 0; i < m_zoneCount; i++)
     {
      if(m_zones[i].name == name) { zone = m_zones[i]; return true; }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|  Update touch counts and bars-since-touch for all zones         |
//+------------------------------------------------------------------+
void CSR_Zones::UpdateTouches(void)
  {
   double point = Point();
   double tolPrice = m_touchTolPips * Point;

   for(int i = 0; i < m_zoneCount; i++)
     {
      if(m_zones[i].state == ZONE_INVALIDATED) continue;

      double high = m_zones[i].priceHigh;
      double low  = m_zones[i].priceLow;

      // check last 3 closed bars for zone touch
      bool touched = false;
      for(int b = 1; b <= 3; b++)
        {
         double o = iOpen(NULL, 0, b);
         double h = iHigh(NULL, 0, b);
         double l = iLow(NULL, 0, b);
         double c = iClose(NULL, 0, b);

         bool barTouches =
            (h >= (low - tolPrice) && l <= (high + tolPrice)) ||   // wick overlap
            (c >= (low - tolPrice) && c <= (high + tolPrice));     // close inside

         if(barTouches) { touched = true; break; }
        }

      if(touched)
        {
         if(m_zones[i].touchCount == 0 || m_zones[i].lastTouchTime == 0)
           { m_zones[i].touchCount = 1; }
         else
           { m_zones[i].touchCount++; }
         m_zones[i].lastTouchTime  = iTime(NULL, 0, 1);
         m_zones[i].barsSinceTouch = 1;
        }
      else
        {
         if(m_zones[i].barsSinceTouch < 300)
            m_zones[i].barsSinceTouch++;
        }
     }
  }

//+------------------------------------------------------------------+
//|  Check invalidation conditions for all zones                     |
//|  Buy zone  → broken when price closes below zoneLow for N bars   |
//|  Sell zone → broken when price closes above zoneHigh for N bars |
//+------------------------------------------------------------------+
void CSR_Zones::CheckInvalidation(int invalidationBars)
  {
   for(int i = 0; i < m_zoneCount; i++)
     {
      if(m_zones[i].state != ZONE_ACTIVE &&
         m_zones[i].state != ZONE_VALIDATED) continue;

      bool broken = false;

      if(m_zones[i].type == ZONE_BUY)
        {
         // Buy zone broken if price closes below zone low for invalidationBars in a row
         bool allBelow = true;
         for(int b = 1; b <= invalidationBars; b++)
           {
            double close = iClose(NULL, 0, b);
            if(close >= m_zones[i].priceLow) { allBelow = false; break; }
           }
         if(allBelow) broken = true;
        }
      else if(m_zones[i].type == ZONE_SELL)
        {
         // Sell zone broken if price closes above zone high for invalidationBars in a row
         bool allAbove = true;
         for(int b = 1; b <= invalidationBars; b++)
           {
            double close = iClose(NULL, 0, b);
            if(close <= m_zones[i].priceHigh) { allAbove = false; break; }
           }
         if(allAbove) broken = true;
        }

      if(broken) InvalidateZone(i);
     }
  }

//+------------------------------------------------------------------+
void CSR_Zones::InvalidateZone(int idx)
  {
   if(idx < 0 || idx >= m_zoneCount) return;
   m_zones[idx].state = ZONE_INVALIDATED;
   if(LogLevel >= 1)
      Print("[ZONE] INVALIDATED: ", m_zones[idx].name,
            " type=", EnumToString(m_zones[idx].type),
            " high=", m_zones[idx].priceHigh,
            " low=", m_zones[idx].priceLow);
  }

//+------------------------------------------------------------------+
SZone* CSR_Zones::GetZone(int idx)
  {
   if(idx < 0 || idx >= m_zoneCount) return NULL;
   return &m_zones[idx];
  }

//+------------------------------------------------------------------+
double SR_Zones::GetZoneHigh(int idx) const
  { return (idx >= 0 && idx < m_zoneCount) ? m_zones[idx].priceHigh : 0; }

double SR_Zones::GetZoneLow(int idx) const
  { return (idx >= 0 && idx < m_zoneCount) ? m_zones[idx].priceLow  : 0; }

ENUM_ZONE_TYPE SR_Zones::GetZoneType(int idx) const
  { return (idx >= 0 && idx < m_zoneCount) ? m_zones[idx].type : ZONE_NONE; }

ENUM_ZONE_STATE SR_Zones::GetZoneState(int idx) const
  { return (idx >= 0 && idx < m_zoneCount) ? m_zones[idx].state : ZONE_NONE; }

//+------------------------------------------------------------------+
string CSR_Zones::StateToString(ENUM_ZONE_STATE s)
  {
   switch(s)
     {
      case ZONE_ACTIVE:      return "ACTIVE";
      case ZONE_VALIDATED:   return "VALIDATED";
      case ZONE_INVALIDATED: return "INVALIDATED";
     }
   return "UNKNOWN";
  }

//+------------------------------------------------------------------+
void CSR_Zones::LogAllZones(int logLevel)
  {
   if(logLevel < 1) return;
   Print("=== ZONE STATUS (total=", m_zoneCount, ") ===");
   for(int i = 0; i < m_zoneCount; i++)
     {
      PrintFormat("[%d] %s | Type=%s | State=%s | High=%.5f Low=%.5f | Touches=%d BarsAge=%d",
                  i, m_zones[i].name,
                  EnumToString(m_zones[i].type),
                  StateToString(m_zones[i].state),
                  m_zones[i].priceHigh, m_zones[i].priceLow,
                  m_zones[i].touchCount, m_zones[i].barsSinceTouch);
     }
  }

#endif
//+------------------------------------------------------------------+