
DefinitionBlock ("", "SSDT", 2, "hack", "DSM", 0x00000000)
{
    
    External (DTGP, MethodObj)
    //RP01 -> SSDT-XHC.dsl / SSDT-TYPC.dsl
    //RP05 -> SSDT-PXSX2ARPT.dsl
    //RP09 -> SSDT-NVME.dsl

    External (_SB.PCI0.RP06.PXSX, DeviceObj)

    Scope (_SB.PCI0.RP06.PXSX)
    {
        Method (_DSM, 4, NotSerialized)
        {
            If (LEqual (Arg2, Zero))
            {
                Return (Buffer (One)
                {
                     0x03                                           
                })
            }

            Store (Package ()
                {
                    "AAPL,slot-name", 
                    Buffer ()
                    {
                        "Built In"
                    }, 

                    "name", 
                    Buffer ()
                    {
                        "PCI Express Card Reader"
                    }, 

                    "model", 
                    Buffer ()
                    {
                        "RTS525A PCI Express Card Reader"
                    }, 

                    "device_type", 
                    Buffer ()
                    {
                        "Card Reader"
                    }, 

                    "hda-gfx", 
                    Buffer ()
                    {
                        "onboard-1"
                    }, 

                    "reg-ltrovr", 
                    Buffer ()
                    {
                         0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                }, Local0)
            DTGP (Arg0, Arg1, Arg2, Arg3, RefOf (Local0))
            Return (Local0)
        }
    }
}