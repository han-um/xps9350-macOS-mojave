//IOThunderboltFamily and AppleThunderboltNHI 
DefinitionBlock ("", "SSDT", 2, "hack", "XHC", 0x00000000)
{
    External (_SB.PCI0.RP01, DeviceObj)    // (from opcode)
    External (_SB.PCI0.RP01.PXSX, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.HS01, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.HS02, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.HS03, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.HS04, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.HS05, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.SS01, DeviceObj)    // (from opcode)
    External (_SB.PCI0.XHC.RHUB.SS02, DeviceObj)    // (from opcode)
    External (_SB.TBFP, MethodObj)    // 1 Arguments (from opcode)
    External (HS01, DeviceObj)    // (from opcode)
    External (HS02, DeviceObj)    // (from opcode)
    External (HS03, DeviceObj)    // (from opcode)
    External (HS04, DeviceObj)    // (from opcode)
    External (HS05, DeviceObj)    // (from opcode)
    External (RHUB, DeviceObj)    // (from opcode)
    External (SS01, DeviceObj)    // (from opcode)
    External (SS02, DeviceObj)    // (from opcode)

    Device (TBON)
    {
        Name (_HID, "TBON1000")  // _HID: Hardware ID
        Method (_INI, 0, NotSerialized)  // _INI: Initialize
        {
            \_SB.TBFP (One)
        }
    }

    Device (_SB.USBX)
    {
        Name (_ADR, Zero)  // _ADR: Address
        Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
        {
            If (LNot (Arg2))
            {
                Return (Buffer (One)
                {
                     0x03                                           
                })
            }

            Return (Package (0x08)
            {
            /*
                "kUSBSleepPortCurrentLimit", 
                0x0BB8, 
                "kUSBSleepPowerSupply", 
                0x0A28, 
                "kUSBWakePortCurrentLimit", 
                0x0BB8, 
                "kUSBWakePowerSupply", 
                0x0C80
               */
                "kUSBSleepPortCurrentLimit", 
                0x05DC, 
                "kUSBSleepPowerSupply", 
                0x05DC, 
                "kUSBWakePortCurrentLimit", 
                0x05DC, 
                "kUSBWakePowerSupply", 
                0x05DC
            })
        }
    }

    Device (UIAC)
    {
        Name (_HID, "UIA00000")  // _HID: Hardware ID
        Name (RMCF, Package (0x02)
        {
            "8086_9d2f", 
            Package (0x04)
            {
                "port-count", 
                Buffer (0x04)
                {
                     0x12, 0x00, 0x00, 0x00                         
                }, 

                "ports", 
                Package (0x0E)
                {
                    "HS01", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0x03, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x01, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "HS02", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0x03, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x02, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "HS03", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0xFF, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x03, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "HS04", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0xFF, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x04, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "HS05", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0xFF, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x05, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "SS01", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0x03, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x0D, 0x00, 0x00, 0x00                         
                        }
                    }, 

                    "SS02", 
                    Package (0x04)
                    {
                        "UsbConnector", 
                        0x03, 
                        "port", 
                        Buffer (0x04)
                        {
                             0x0E, 0x00, 0x00, 0x00                         
                        }
                    }
                }
            }
        })
    }

    Scope (\_SB.PCI0.XHC)
    {
        Scope (RHUB)
        {
            Scope (HS01)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0x03, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (HS02)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0x03, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (HS03)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0xFF, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (HS04)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0xFF, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (HS05)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0xFF, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (SS01)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0x03, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }

            Scope (SS02)
            {
                Name (_UPC, Package (0x04)  // _UPC: USB Port Capabilities
                {
                    0xFF, 
                    0x03, 
                    Zero, 
                    Zero
                })
                Name (_PLD, Package (0x01)  // _PLD: Physical Location of Device
                {
                    Buffer (0x10)
                    {
                        /* 0000 */  0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                        /* 0008 */  0x30, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
                    }
                })
            }
        }

        Method (MBSD, 0, NotSerialized)
        {
            Return (One)
        }
    }

    Scope (_SB.PCI0.RP01)
    {
        Method (_PS0, 0, Serialized)  // _PS0: Power State 0
        {
            \_SB.TBFP (One)
        }

        Method (_PS3, 0, Serialized)  // _PS3: Power State 3
        {
            \_SB.TBFP (Zero)
        }
        
        Method (_DSM, 4, NotSerialized)
        {
	        If (LEqual (Arg2, Zero))
	        {
		        Return (Buffer (One){0x03})
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

    Scope (_SB.PCI0.RP01.PXSX)
    {
        /*
        Name (_ADR, Zero)
		Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
		{
			If (!Arg2)
			{
				Return (Buffer (One) { 0x03 })
			}

			Return (Package (0x02)
			{
				"PCI-Thunderbolt",
				One
			})
        }
        */
        
        Method (_RMV, 0, NotSerialized)  // _RMV: Removal Status
        {
            Return (One)
        }

        Method (_STA, 0, NotSerialized)  // _STA: Status
        {
            Return (0x0F)
        }
        
        Device (DSB0)
		{
			Name (_ADR, Zero)  // _ADR: Address
			Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
			{
				If (!Arg2)
				{
					Return (Buffer (One) { 0x03 })
				}

				Return (Package (0x02)
				{
						"PCIHotplugCapable",
						Zero
				})
			}

			Device (NHI0)
			{
				Name (_ADR, Zero)  // _ADR: Address
                 /*
				Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
				{
					If (!Arg2)
					{
						Return (Buffer (One) { 0x03 })
					}

					Return (Package (0x02)
					{
						"power-save",
						Zero
					})
				}
                 */
			}
        }
        
	    Device (DSB1)
	    {
			Name (_ADR, 0x00010000)  // _ADR: Address
        }
        
        Device (DSB2)
        {
            Name (_ADR, 0x00020000)  // _ADR: Address
            Method (_DSM, 4, NotSerialized)  // _DSM: Device-Specific Method
            {
                If (LEqual (Arg2, Zero))
                {
                    Return (Buffer (One) { 0x03 })
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

