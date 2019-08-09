
DefinitionBlock ("", "SSDT", 2, "hack", "TYPC", 0x00000000)
{
    External (_SB_.PCI0.RP01, DeviceObj)    // (from opcode)
    External (_SB_.PCI0.RP01.PXSX, DeviceObj)    // (from opcode)
    External (_SB_.TBFP, MethodObj)    // 1 Arguments (from opcode)
    External (RMDT, DeviceObj)    // (from opcode)
    External (RMDT.PUSH, MethodObj)    // 1 Arguments (from opcode)

    Device (TBON)
    {
        Name (_HID, "TBON1000")  // _HID: Hardware ID
        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            \RMDT.PUSH ("TBON._INI: Powering TBFP")
            \_SB.TBFP (One)
        }
    }

    Scope (_SB.PCI0.RP01)
    {
        Method (_PS0, 0, Serialized)  // _PS0: Power State 0
        {
            \RMDT.PUSH ("RP01.PXSX._PS0: Powering TBFP")
            \_SB.TBFP (One)
        }

        Method (_PS3, 0, Serialized)  // _PS3: Power State 3
        {
            \RMDT.PUSH ("RP01.PXSX._PS3: de-Powering TBFP")
            \_SB.TBFP (Zero)
        }
    }

    Scope (_SB.PCI0.RP01.PXSX)
    {
        Method (_RMV, 0, NotSerialized)  // _RMV: Removal Status
        {
            Return (One)
        }

        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            Return (0x0F)
        }

        Device (DSB2)
        {
            Name (_ADR, 0x00020000)  // _ADR: Address
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
                    "PCIHotplugCapable", 
                    Zero
                })
            }

            Device (XHC2)
            {
                Name (_ADR, Zero)  // _ADR: Address
                Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
                {
                    If (LEqual (Arg2, Zero))
                    {
                        Return (Buffer (One)
                        {
                             0x03                                           
                        })
                    }

                    Return (Package (0x06)
                    {
                        "USBBusNumber", 
                        Zero, 
                        "AAPL,xhci-clock-id", 
                        One, 
                        "UsbCompanionControllerPresent", 
                        Zero
                    })
                }

                Device (RHUB)
                {
                    Name (_ADR, Zero)  // _ADR: Address
                    Device (SSP1)
                    {
                        Name (_ADR, One)  // _ADR: Address
                        Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                        {
                            0xFF, 
                            0x09, 
                            Zero, 
                            Zero
                        })
                        Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                        {
                            Buffer (0x10)
                            {
                                /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                /* 0008 */  0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                            }
                        })
                        Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
                        {
                            If (LEqual (Arg2, Zero))
                            {
                                Return (Buffer (One)
                                {
                                     0x03                                           
                                })
                            }

                            Return (Package (0x04)
                            {
                                "UsbCPortNumber", 
                                0x02, 
                                "UsbCompanionPortPresent", 
                                Zero
                            })
                        }
                    }

                    Device (SSP2)
                    {
                        Name (_ADR, 0x03)  // _ADR: Address
                        Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                        {
                            0xFF, 
                            0x09, 
                            Zero, 
                            Zero
                        })
                        Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                        {
                            Buffer (0x10)
                            {
                                /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                /* 0008 */  0x31, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                            }
                        })
                    }
                }
            }
        }
    }
}

