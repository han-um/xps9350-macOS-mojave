
DefinitionBlock ("", "SSDT", 1, "syscl", "ARPT", 0x00003000)
{
    External (_SB_.PCI0.RP05, DeviceObj)
    //External (_SB_.PCI0.RP05.PXSX, DeviceObj)
    External (_SB_.PCI0.RP05.ARPT, DeviceObj)
    External (DTGP, MethodObj)

    Scope (\_SB.PCI0.RP05)
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
                            "M.2 key B"
                        }, 

                        "name", 
                        Buffer ()
                        {
                            "Broadcom 802.11ac Wireless Network Adapter"
                        }, 

                        "model", 
                        Buffer ()
                        {
                            "Broadcom 802.11ac Wireless Network Adapter"
                        }, 

                        "device_type", 
                        Buffer ()
                        {
                            "WLAN Device"
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
        /*
        Scope (PXSX)
        {
            Name (_STA, Zero)  // _STA: Status
        }
        
        Device (ARPT)
        */
        Scope (ARPT)
        {
            Name (_ADR, Zero)  // _ADR: Address
            /*
            Name (_PRW, Package (0x02)  // _PRW: Power Resources for Wake
            {
                0x09, 
                0x04
            })*/
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If (LEqual (Arg2, Zero))
                {
                    Return (Buffer (One)
                    {
                         0x03                                           
                    })
                }

                Return (Package (0x02)
                {
                    "reg-ltrovr", 
                    Buffer (0x08)
                    {
                         0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }
        }
    }

    Store ("SSDT-ARPT-RP05 github.com/syscl", Debug)
}

