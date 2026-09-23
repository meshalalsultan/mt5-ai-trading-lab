//+------------------------------------------------------------------+
//| EXP009_mock.mqh                                                  |
//| EXP-009 Test B1-R1: controllable mock execution interface.       |
//| Implements ONLY the send-side of the contract (claim producer).  |
//| Evidence feeding (positions/orders/deals) is done by the tests   |
//| via EXP009_core snapshot helpers. NO OrderSend/CTrade anywhere.  |
//+------------------------------------------------------------------+
#ifndef EXP009_MOCK_MQH
#define EXP009_MOCK_MQH

#include <MASK_EDU_EXP009\EXP009_core.mqh>

class CE9Mock
  {
private:
   bool m_scriptDone;      // scripted retcode DONE for the next send
   ulong m_nextOrder;
   ulong m_nextDeal;
public:
   int   sendCount;        // every order send (open or close)
   int   openCount;
   int   closeCount;
   bool  failOpen;         // scripted: block open sends (still counts)
   bool  failClose;        // scripted: block close sends
   bool  noTicket;         // scripted: succeed but the claim carries NO order reference

   CE9Mock()
     {
      m_scriptDone=true;
      m_nextOrder=1000;
      m_nextDeal=5000;
      sendCount=0; openCount=0; closeCount=0;
      failOpen=false; failClose=false; noTicket=false;
     }
   //--- script the next send result claim
   void ScriptDone(const bool done) { m_scriptDone=done; }

   //--- execute an action produced by the core; returns the claim.
   void DoAction(const E9Action &a,E9Claim &claim)
     {
      claim.has=true;
      claim.done=false;
      claim.orderTicket=0; claim.dealTicket=0;
      claim.volume=0.0; claim.dir=a.dir;
      if(a.type==1) // open
        {
         sendCount++; openCount++;
         if(failOpen) { claim.done=false; return; }
         claim.done=m_scriptDone;
         claim.orderTicket=m_nextOrder++;
         claim.dealTicket=m_nextDeal++;
         if(noTicket){ claim.orderTicket=0; claim.dealTicket=0; }
         claim.volume=a.volume;
        }
      else if(a.type==2) // close
        {
         sendCount++; closeCount++;
         if(failClose) { claim.done=false; return; }
         claim.done=m_scriptDone;
         claim.orderTicket=m_nextOrder++;
         claim.dealTicket=m_nextDeal++;
         if(noTicket){ claim.orderTicket=0; claim.dealTicket=0; }
         claim.volume=a.volume;
        }
      else
        claim.has=false;
     }

   //--- construct a claim directly (for ticks without an action)
   void MakeClaim(const bool done,const ulong order,const ulong deal,
                  const int dir,const double vol,E9Claim &c)
     {
      c.has=true; c.done=done; c.orderTicket=order; c.dealTicket=deal;
      c.volume=vol; c.dir=dir;
     }
  };

#endif