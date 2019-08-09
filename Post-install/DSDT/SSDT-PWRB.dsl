
DefinitionBlock ("", "SSDT", 2, "hack", "PWRB", 0x00000000)
{
    External (_SB_.PWRB, DeviceObj)    // (from opcode)
    External (_SB_.SLPB, DeviceObj)    // (from opcode)

    Scope (\_SB.PWRB)
    {
        Name (_UID, 0xAA)  // _UID: Unique ID
    }

    Scope (\_SB.SLPB)
    {
        Name (_STA, 0x0B)  // _STA: Status
    }
}

