//
//  main.m
//  USBFix
//
//  Created by maz-1 on 2018/12/18.
//  Copyright © 2018 maz-1. All rights reserved.
//

#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <CoreServices/CoreServices.h>
#include <CoreFoundation/CFString.h>
#include <SystemConfiguration/SystemConfiguration.h>
#include <mach/mach_port.h>
#include <mach/mach_interface.h>
#include <mach/mach_init.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFBundle.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOMessage.h>
#include <IOKit/ps/IOPowerSources.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <AppKit/AppKit.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <sys/types.h>
#include <sys/stat.h>

#include <DiskArbitration/DiskArbitration.h>

//Enum for pci device eject/rescan
enum
{
    kIOPCIProbeOptionDone      = 0x80000000,
    kIOPCIProbeOptionEject     = 0x00100000,
    kIOPCIProbeOptionNeedsScan = 0x00200000,
};

//IOPMLibPrivate.h
#define kIOPMDynamicStoreSettingsKey "State:/IOKit/PowerManagement/CurrentSettings"
#define kIOPMACPowerKey "AC Power"
#define kIOHibernateModeKey "Hibernate Mode"
#define kIOPMAutoPowerOffEnabledKey "AutoPowerOff Enabled"
//IOKit/pwr_mgt/IOPM.h
#define kIOPMDeepSleepEnabledKey "Standby Enabled"
//pmset.c
#define kMaxArgStringLength 49

NSMutableArray *ejectMediaArr = nil;
DASessionRef session = nil;
bool run = true;
struct stat consoleinfo;

pthread_t usb_eject_id;
CFRunLoopRef usbEjectRunLoop = NULL;
pthread_t xhc2_id;
CFRunLoopRef XHC2RunLoop = NULL;
CFRunLoopRef powerRunLoop = NULL;
io_connect_t root_port;
io_object_t notifierObject;
IONotificationPortRef  usbEjectNotifyPort;
IONotificationPortRef  XHC2NotifyPort;
bool xhc2EjectBlock = false;
int xhc2EjectStatus = 1;

NSString *doShellScript(NSString *cmd_launch_path, NSArray *cmd_pt) {
    NSTask *task = [[NSTask alloc] init]; // Make a new task
    [task setLaunchPath: cmd_launch_path]; // Tell which command we are running
    [task setArguments: cmd_pt];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    [task launch];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    //[task release]; //Release the task into the world, thus destroying it.
    return string;
}

static IOReturn GetUSBDeviceInterface(io_service_t usbDevice, IOUSBDeviceInterface650 ***iface)
{
    IOReturn ret;
    SInt32 score = 0;
    IOCFPlugInInterface **plugInInterface = NULL;
    //IOCFPlugInInterface **  interface;
    //IUnknownVTbl **     iunknown;
    
    ret = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID,
                                             kIOCFPlugInInterfaceID, &plugInInterface, &score);

    if (ret != kIOReturnSuccess || !plugInInterface) {
        //printf("Failed to create PluginInterface: 0x%x\n", ret);
        return ret;
    }

    (*plugInInterface)->QueryInterface(plugInInterface,
            CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID650),
            (LPVOID*)iface);
    
    (*plugInInterface)->Release(plugInInterface);
 
    return 0;
}

/*
io_service_t IOGetParent(io_service_t child, int layers)
{
	io_service_t tmp = child;
	io_service_t tmp2 = 0;
	for (int i = 0; i < layers; i++)
	{
		if (i & 1)
		{
			IOObjectRelease(tmp);
			IORegistryEntryGetParentEntry(tmp2, kIOServicePlane, &tmp);
		}
		else
		{
			IOObjectRelease(tmp2);
			IORegistryEntryGetParentEntry(tmp, kIOServicePlane, &tmp2);
		}
	}
	if (layers & 1)
	{
		if (layers > 1)
			IOObjectRelease(tmp);
		return tmp2;
	}
	IOObjectRelease(tmp2);
	return tmp;
}
*/

io_service_t IOGetParentPXSX(io_service_t child)
{
	io_service_t tmp = child;
	io_service_t tmp2 = 0;
	io_name_t name;
	IORegistryEntryGetName(child, name);
	int i;
	bool notFound = false;
	kern_return_t error;
	for (i = 1; strcmp(name, "PXSX"); i++)
	{
		if (i & 1)
		{
			IOObjectRelease(tmp2);
			error = IORegistryEntryGetParentEntry(tmp, kIOServicePlane, &tmp2);
			IORegistryEntryGetName(tmp2, name);
			if (error != KERN_SUCCESS)
			{
				notFound = true;
				break;
			}
		}
		else
		{
			IOObjectRelease(tmp);
			error = IORegistryEntryGetParentEntry(tmp2, kIOServicePlane, &tmp);
			IORegistryEntryGetName(tmp, name);
			if (error != KERN_SUCCESS)
			{
				notFound = true;
				break;
			}
		}
	}
	//fprintf(stderr, "layers:%d\n", i);
	if (i & 1)
	{
		if (i > 1)
			IOObjectRelease(tmp2);
		if (notFound)
			return 0;
		return tmp;
	}
	if (i > 1)
		IOObjectRelease(tmp);
	if (notFound)
		return 0;
	return tmp2;
}

//trigger RP01 rescan
kern_return_t rp01Probe(uint32_t options)
{
	kern_return_t kernel_return_status = 0;
	io_service_t IOElectrifyBridgeIOService = 0;
	io_connect_t DataConnection;
	uint32_t connectiontype = 0;
	io_iterator_t itThis;
	io_name_t name;
	//IOElectrifyBridgeIOService = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/RP01@1C/IOPP/IOElectrifyBridge");
	if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCI2PCIBridge"), &itThis) == KERN_SUCCESS)
    {
    	io_service_t service;
	    while((service = IOIteratorNext(itThis)))
        {
			io_iterator_t itChild;
			if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itChild) == KERN_SUCCESS)
			{
				io_service_t child;
				while((child = IOIteratorNext(itChild)))
				{
					IORegistryEntryGetName(child, name);
					if (!strcmp(name, "IOElectrifyBridge"))
					{
						IOElectrifyBridgeIOService = child;
						break;
					}
					IOObjectRelease(child);
				}
				IOObjectRelease(itChild);
			}
		}
		IOObjectRelease(service);
    }
	IOObjectRelease(itThis);
	
    if (!IOElectrifyBridgeIOService)
    {
        fprintf(stderr, "Could not locate IOElectrify kext. Ensure it is loaded. %08x.\n", kernel_return_status);
        return kernel_return_status;
	}
    kernel_return_status = IOServiceOpen(IOElectrifyBridgeIOService, mach_task_self(), connectiontype, &DataConnection);
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "Failed to open IOElectrifyBridge IOService: %08x.\n", kernel_return_status);
        goto EXIT;
	}
    uint32_t inputCount = 1; // Number of input arguments
    uint32_t outputCount = 1; // Number of elements in output
    uint64_t input = options; // Array of input scalars
	uint64_t output; // Array of output scalars
	kernel_return_status = IOConnectCallScalarMethod(DataConnection, connectiontype, &input, inputCount, &output, &outputCount);
	fprintf(stderr, "probe option 0x%x, result 0x%x\n", options, kernel_return_status);
    
    EXIT:
    IOServiceClose(DataConnection);
    IOObjectRelease(IOElectrifyBridgeIOService);
	return kernel_return_status;
}

kern_return_t IOElectrifyCMD(uint32_t connectiontype, uint64_t input)
{
	kern_return_t kernel_return_status = 0;
	io_service_t IOElectrifyIOService = 0;
	io_connect_t DataConnection;
	//uint32_t connectiontype = 0;
	//IOElectrifyIOService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOElectrify"));
	IOElectrifyIOService = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleACPIPlatformExpert/WMTF/IOElectrify");
    if (!IOElectrifyIOService)
    {
        fprintf(stderr, "could not locate IOElectrify kext. Ensure it is loaded. %08x.\n", kernel_return_status);
        return kernel_return_status;
	}
    kernel_return_status = IOServiceOpen(IOElectrifyIOService, mach_task_self(), connectiontype, &DataConnection);
    if (kernel_return_status != kIOReturnSuccess)
    {
        fprintf(stderr, "failed to open IOElectrify IOService: %08x.\n", kernel_return_status);
        goto EXIT;
	}
    uint32_t inputCount = 1; // Number of input arguments
    uint32_t outputCount = 1; // Number of elements in output
    //uint64_t input = (uint64_t)onoff; // Array of input scalars
	uint64_t output; // Array of output scalars
	kernel_return_status = IOConnectCallScalarMethod(DataConnection, connectiontype, &input, inputCount, &output, &outputCount);
	fprintf(stderr, "Result: %d\n", kernel_return_status);
    
    IOServiceClose(DataConnection);
    EXIT:
    IOObjectRelease(IOElectrifyIOService);
	return kernel_return_status;
}

kern_return_t ThunderboltForcePower(bool onoff)
{
    fprintf(stderr, "ThunderboltForcePower ");
    return IOElectrifyCMD(0, (uint64_t)onoff);
}

kern_return_t IOElectrifyTogglePowerHook(uint32_t onoff)
{
    fprintf(stderr, "IOElectrifyTogglePowerHook ");
    return IOElectrifyCMD(1, onoff);
}

unsigned int GetUsbLocation(io_service_t usb)
{
	unsigned int locationID = 0;
    CFTypeRef cfTypeReference = IORegistryEntryCreateCFProperty(usb, 
                                                                CFSTR(kUSBDevicePropertyLocationID),
                                                                kCFAllocatorDefault,
                                                                kNilOptions);
    if( cfTypeReference )
    {
        CFNumberGetValue( (CFNumberRef)cfTypeReference, kCFNumberSInt32Type, &locationID);
        CFRelease( cfTypeReference );
    }
	return locationID;
}

int unfreezeXHC2()
{
    kern_return_t result = 1;
    io_iterator_t itThis;
    io_service_t service;
    io_name_t name;
    IOUSBDeviceInterface650 **iface;
    bool xhc2Found = false;
    
            if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleUSBXHCIPCI"), &itThis) == KERN_SUCCESS)
            {
                while((service = IOIteratorNext(itThis)))
                {
                    IORegistryEntryGetName(service, name);
                    if (!strcmp(name, "XHC2"))
                    {
                            xhc2Found = true;
                            io_iterator_t itUsb;
                            if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itUsb) == KERN_SUCCESS)
                            {
                                io_service_t usbPort;
                                while((usbPort = IOIteratorNext(itUsb)))
                                {
                                    io_service_t usbDevice;
                                    IORegistryEntryGetChildEntry(usbPort, kIOServicePlane, &usbDevice);
                                    if (!GetUSBDeviceInterface(usbDevice, &iface))
                                    {
                                        kern_return_t r = (*iface)->USBDeviceReEnumerate(iface, kUSBReEnumerateReleaseDeviceMask);
                                        printf("0x%08x unfreeze result: 0x%x\n", GetUsbLocation(usbDevice), r);
                                        result = 0;
                                    }
                                    IOObjectRelease(usbDevice);
                                    IOObjectRelease(usbPort);
                                }
                            }
                    }
                    IOObjectRelease(service);
                }
                IOObjectRelease(itThis);
            }
    //if (!xhc2Found)
    //    fprintf(stderr, "XHC2 not found.\n");
    return result;
}

int ejectXHC2(bool force)
{
    //io_registry_entry_t reg = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/RP01@1C/IOPP/PXSX@0/IOPP/DSB2@2/IOPP/XHC2@0");
    //struct stat consoleinfo;
    //xhc2EjectBlock = true;
    stat("/dev/console", &consoleinfo);
    int uid = getuid();
    kern_return_t result = 1;
    io_iterator_t itThis;
    io_service_t service;
    io_name_t name;
    IOUSBDeviceInterface650 **iface;
    bool xhc2Found = false;
    bool attached = false;
    
    io_service_t ThunderboltNHI = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOThunderboltController"));
    if (!ThunderboltNHI)
    {
            if (IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("AppleUSBXHCIPCI"), &itThis) == KERN_SUCCESS)
            {
                while((service = IOIteratorNext(itThis)))
                {
                    IORegistryEntryGetName(service, name);
                    if (!strcmp(name, "XHC2"))
                    {
                            xhc2Found = true;
                            io_service_t parent;
                            io_iterator_t itUsb;
                            if (IORegistryEntryGetChildIterator(service, kIOServicePlane, &itUsb) == KERN_SUCCESS)
                            {
                                io_service_t usbPort;
                                while((usbPort = IOIteratorNext(itUsb)))
                                {
                                    io_service_t usbDevice;
                                    IORegistryEntryGetChildEntry(usbPort, kIOServicePlane, &usbDevice);
                                    if (!GetUSBDeviceInterface(usbDevice, &iface))
                                    {
                                        attached = true;
                                        if (force)
                                            (*iface)->USBDeviceReEnumerate(iface, kUSBReEnumerateCaptureDeviceMask);
                                    }
                                    IOObjectRelease(usbDevice);
                                    IOObjectRelease(usbPort);
                                }
                            }
							if (attached)
                            	usleep(100000);
                            //IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent);
							parent = IOGetParentPXSX(service);
                            if (force || !attached)
                            {
                                fprintf(stderr, "XHC2 will be closed.\n");
                                seteuid(consoleinfo.st_uid);
                                result = IORegistryEntrySetCFProperty(parent, CFSTR("IOPCIOnline"), kCFBooleanFalse);
                                fprintf(stderr, "Result: 0x%lx\n", (unsigned long)result);
                                seteuid(uid);
                                usleep(500000);
                            }
                            rp01Probe(kIOPCIProbeOptionNeedsScan | kIOPCIProbeOptionDone);
                            IOObjectRelease(parent);
                    }
                    IOObjectRelease(service);
                }
                IOObjectRelease(itThis);
            }
    }
    else
    {
        IOObjectRelease(ThunderboltNHI);
        fprintf(stderr, "Thunderbolt driver loaded, will not eject.\n");
        //xhc2EjectBlock = false;
        return result;
    }
    if (!xhc2Found)
        fprintf(stderr, "XHC2 not found. 0x%x\n", force);
    //usleep(100000);
    //xhc2EjectBlock = false;
    return result;
}


void setHibernationMode()
{
    
    //show_live_pm_settings
    SCDynamicStoreRef ds = SCDynamicStoreCreate(NULL, CFSTR("pmset"), NULL, NULL);
    CFDictionaryRef live = SCDynamicStoreCopyValue(ds, CFSTR(kIOPMDynamicStoreSettingsKey));
    if(!live) 
        return;
    CFMutableDictionaryRef live_mutable = CFDictionaryCreateMutableCopy(NULL, 0, live);
    //show_pm_settings_dict(live, 0, true, true);
    char ps[kMaxArgStringLength];
    CFStringRef activeps = NULL;
    int count = (int)CFDictionaryGetCount(live);
    CFStringRef *keys = (CFStringRef *)malloc(count * sizeof(void *));
    CFTypeRef *vals = (CFTypeRef *)malloc(count * sizeof(void *));
    int val_n = 0;
    bool success;
    bool modified = false;
    const int zero = 0;
    CFNumberRef Zero = CFNumberCreate(NULL, kCFNumberIntType, &zero);
    CFTypeRef ps_blob = IOPSCopyPowerSourcesInfo();
    if(ps_blob) {
        activeps = IOPSGetProvidingPowerSourceType(ps_blob);
    }
    if(!activeps) activeps = CFSTR(kIOPMACPowerKey);
    if(activeps) CFRetain(activeps);
    if(!keys || !vals) 
        goto exit;
    CFDictionaryGetKeysAndValues(live, (const void **)keys, (const void **)vals);
    
    for(int i=0; i<count; i++)
    {
        if (!CFStringGetCString(keys[i], ps, sizeof(ps), kCFStringEncodingMacRoman)) 
            continue;
        //if ( !IOPMFeatureIsAvailable(keys[i], CFSTR(kIOPMACPowerKey)) )
        //    continue;
        if (strcmp(ps, kIOHibernateModeKey) == 0) // hibernatemode
        {
            success = CFNumberGetValue(vals[i], kCFNumberIntType, &val_n);
            //printf("hibernatemod %d\n", val_n);
            if (success && val_n != 0)
            {
                modified = true;
                CFDictionarySetValue(live_mutable, keys[i], Zero);
                //delete sleepimage
                NSString *filePath = @"/var/vm/sleepimage";
                NSURL *fileURL = [NSURL fileURLWithPath:filePath];
                NSNumber *fileSizeValue = nil;
                NSError *error = nil;
                [fileURL getResourceValue:&fileSizeValue
                                   forKey:NSURLFileSizeKey
                                    error:&error];
                if (fileSizeValue && [fileSizeValue intValue] > 0)
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            }
        }
        else if (strcmp(ps, kIOPMAutoPowerOffEnabledKey) == 0) // autopoweroff
        {
            success = CFNumberGetValue(vals[i], kCFNumberIntType, &val_n);
            //printf("autopoweroff %d\n", val_n);
            if (success && val_n != 0)
            {
                modified = true;
                CFDictionarySetValue(live_mutable, keys[i], Zero);
            }
        }
        else if (strcmp(ps, kIOPMDeepSleepEnabledKey) == 0) // standby
        {
            success = CFNumberGetValue(vals[i], kCFNumberIntType, &val_n);
            //printf("standby %d\n", val_n);
            if (success && val_n != 0)
            {
                modified = true;
                CFDictionarySetValue(live_mutable, keys[i], Zero);
            }
        }
        //printf("|%s|\n", CFStringGetCStringPtr(keys[i], kCFStringEncodingUTF8));
    }
    if (modified) 
        SCDynamicStoreSetValue(ds, CFSTR(kIOPMDynamicStoreSettingsKey), live_mutable);
    exit:
        if (ps_blob) CFRelease(ps_blob);
        if (activeps) CFRelease(activeps);
        free(keys);
        free(vals);
        CFRelease(live);
        CFRelease(live_mutable);
        CFRelease(ds);
        CFRelease(Zero);
    /*
        
            //set hibernate mode
            NSString *pmsetStr = doShellScript(@"/usr/bin/pmset", [NSArray arrayWithObjects: @"-g", nil]);
            NSError *error = NULL;
            NSRegularExpression *regexPmset = [NSRegularExpression regularExpressionWithPattern:@"^\\s*([a-z]+)\\s+(\\S+).*$"
                                                                           options:NSRegularExpressionAnchorsMatchLines
                                                                             error:&error];
            NSArray *pmsetKeys = [regexPmset matchesInString:pmsetStr options:0 range:NSMakeRange(0, [pmsetStr length])];
            for (NSTextCheckingResult *match in pmsetKeys) {
                NSString *matchKey = [pmsetStr substringWithRange:[match rangeAtIndex:1]];
                NSString *matchValue = [pmsetStr substringWithRange:[match rangeAtIndex:2]];
                if ([matchKey isEqualToString:@"hibernatemode"] && ![matchValue isEqualToString:@"0"])
                {
                    doShellScript(@"/usr/bin/pmset", [NSArray arrayWithObjects: @"hibernatemode", @"0", nil]);
                    //delete sleepimage
                    NSString *filePath = @"/var/vm/sleepimage";
                    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
                    NSNumber *fileSizeValue = nil;
                    NSError *error = nil;
                    [fileURL getResourceValue:&fileSizeValue
                                       forKey:NSURLFileSizeKey
                                        error:&error];
                    if (fileSizeValue && [fileSizeValue intValue] > 0)
                        [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
                }
                        
                else if ([matchKey isEqualToString:@"autopoweroff"] && ![matchValue isEqualToString:@"0"])
                        doShellScript(@"/usr/bin/pmset", [NSArray arrayWithObjects: @"autopoweroff", @"0", nil]);
                else if ([matchKey isEqualToString:@"standby"] && ![matchValue isEqualToString:@"0"])
                        doShellScript(@"/usr/bin/pmset", [NSArray arrayWithObjects: @"standby", @"0", nil]);
            }
    */        
}

//
// Respect OS signals
//

void sigHandler(int signo)
{
    printf("\nsigHandler: Received signal %d\n", signo); // Technically this print is not async-safe, but so far haven't run into any issues
    switch (signo)
    {
        // Need to be sure object gets released correctly on any kind of quit
        // notification, otherwise the program's left still running!
        case SIGINT: // CTRL + c or Break key
        case SIGTERM: // Shutdown/Restart
        case SIGHUP: // "Hang up" (legacy)
        case SIGKILL: // Kill
        case SIGTSTP: // Close terminal from x button
            run = false;
            break; // SIGTERM, SIGINT mean we must quit, so do it gracefully
        default:
            break;
    }
}

void UsbEjectCallback(void *refcon, io_iterator_t deviceList)
{
	if (xhc2EjectBlock)
		return;
    fprintf(stderr, "UsbEjectCallback.\n");
	xhc2EjectBlock = true;
    
	//usleep(50000);
    kern_return_t       kr;
    CFDictionaryRef     properties;
    io_registry_entry_t device;
    
    while ((device = IOIteratorNext(deviceList))) {
        kr = IORegistryEntryCreateCFProperties(
                 device, (CFMutableDictionaryRef *)&properties,
                 kCFAllocatorDefault, kNilOptions);
        if (kr == KERN_SUCCESS)
            ejectXHC2(false);
            
        if (properties)
            CFRelease(properties);
        if (device)
            IOObjectRelease(device);
    }
    
    /*
    io_registry_entry_t device;
    while ((device = IOIteratorNext(deviceList))) {IOObjectRelease(device);}
    ejectXHC2(false);
    */
	xhc2EjectBlock = false;
}

void UsbEjectWatcherThread(void)
{
    CFMutableDictionaryRef match;
    //IONotificationPortRef  usbEjectNotifyPort;
    CFRunLoopSourceRef     notificationEjectRLSource;
    io_iterator_t          notificationOut;
    io_service_t device;

    //pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
	//pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);
    
    //AppleUSBXHCIPCI kIOUSBDeviceClassName
    if (!(match = IOServiceMatching(kIOUSBDeviceClassName))) {
        fprintf(stderr, "*** failed to create matching dictionary.\n");
        exit(1);
    }
    usbEjectNotifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    notificationEjectRLSource = IONotificationPortGetRunLoopSource(usbEjectNotifyPort);
    usbEjectRunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(usbEjectRunLoop, notificationEjectRLSource,
                       kCFRunLoopDefaultMode);
    CFRetain(match);
    //kIOFirstMatchNotification kIOTerminatedNotification
    IOServiceAddMatchingNotification(
        usbEjectNotifyPort,
        kIOTerminatedNotification,
        match,
        UsbEjectCallback,
        NULL,
        &notificationOut);
    while ((device = IOIteratorNext(notificationOut))) {IOObjectRelease(device);}
    
    CFRunLoopRun();
}


void XHC2Callback(void *refcon, io_iterator_t deviceList)
{
	if (xhc2EjectBlock)
		return;
    fprintf(stderr, "XHC2Callback.\n");
	xhc2EjectBlock = true;
    
	sleep(1);
    io_registry_entry_t device;
    
    while ((device = IOIteratorNext(deviceList))) {
            IOObjectRelease(device);
    }
    
	xhc2EjectBlock = false;
}

void XHC2WatcherThread(void)
{
    CFMutableDictionaryRef match;
    //IONotificationPortRef  XHC2NotifyPort;
    CFRunLoopSourceRef     notificationXHC2RLSource;
    io_iterator_t          notificationOut;
    io_service_t device;

    //pthread_setcancelstate(PTHREAD_CANCEL_ENABLE, NULL);
	//pthread_setcanceltype(PTHREAD_CANCEL_ASYNCHRONOUS, NULL);
    
    //AppleUSBXHCIPCI kIOUSBDeviceClassName
    if (!(match = IOServiceMatching("AppleUSBXHCIPCI"))) {
        fprintf(stderr, "*** failed to create matching dictionary.\n");
        exit(1);
    }
    XHC2NotifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    notificationXHC2RLSource = IONotificationPortGetRunLoopSource(XHC2NotifyPort);
    XHC2RunLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(XHC2RunLoop, notificationXHC2RLSource,
                       kCFRunLoopDefaultMode);
    CFRetain(match);
    //kIOFirstMatchNotification kIOTerminatedNotification
    IOServiceAddMatchingNotification(
        XHC2NotifyPort,
        kIOFirstMatchNotification,
        match,
        XHC2Callback,
        NULL,
        &notificationOut);
    while ((device = IOIteratorNext(notificationOut))) {IOObjectRelease(device);}
    
    CFRunLoopRun();
}

unsigned char * bin_to_strhex(const unsigned char *bin, unsigned int binsz,
                                  unsigned char **result)
{
  unsigned char     hex_str[]= "0123456789abcdef";
  unsigned int      i;
  if (!(*result = (unsigned char *)malloc(binsz * 2 + 1)))
    return (NULL);
  (*result)[binsz * 2] = 0;
  if (!binsz)
    return (NULL);
  for (i = 0; i < binsz; i++)
    {
      (*result)[i * 2 + 0] = hex_str[(bin[i] >> 4) & 0x0F];
      (*result)[i * 2 + 1] = hex_str[(bin[i]     ) & 0x0F];
    }
  return (*result);
}

void SendQuitToProcess(NSString* named)
{   

    for ( id app in [[NSWorkspace sharedWorkspace] runningApplications] ) 
    {
        if ( [named isEqualToString:[[app executableURL] lastPathComponent]]) 
        {
            [(NSTask*)app terminate];
        }
    }

}

void fixRtlWlan(NSString *content)
{
    BOOL isDir;
    NSString *appPath = @"/Applications/Wireless Network Utility.app";
    if (![[NSFileManager defaultManager] fileExistsAtPath:appPath isDirectory:&isDir] || !isDir)
        return;
	io_service_t IORTLWlanUSB = 0;
    //RtWlanU1827 RtWlanU
	IORTLWlanUSB = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("RtWlanU"));
    if (!IORTLWlanUSB)
        IORTLWlanUSB = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("RtWlanU1827"));
    if (IORTLWlanUSB)
    {
        CFDataRef res = IORegistryEntryCreateCFProperty(IORTLWlanUSB, CFSTR("IOMACAddress"), kCFAllocatorDefault, 0);
        if (res)
        {
            SendQuitToProcess(@"Wireless Network Utility");
            unsigned char * buf = (unsigned char*) CFDataGetBytePtr(res);
            unsigned char * result;
            //sizeof(buf)
            fprintf(stderr, "RTLWlan MAC Address: %s\n", bin_to_strhex(buf, 6, &result));
            //NSString *configPath = @"/Applications/Wireless Network Utility.app/";
            NSString *configPath = [appPath stringByAppendingString:@"/"];
            configPath = [configPath stringByAppendingString:[NSString stringWithCString:(const char *)result encoding:NSASCIIStringEncoding]];
            configPath = [configPath stringByAppendingString:@"rfoff.rtl"];
            free(result);
            //NSString *content = @"1";
            [content writeToFile:configPath 
                     atomically:NO 
                     encoding:NSStringEncodingConversionAllowLossy 
                     error:nil];
            [[NSWorkspace sharedWorkspace] launchApplication:@"Wireless Network Utility"];
        }
        IOObjectRelease(IORTLWlanUSB);
    }
}


void ejectMedia(bool eject)
{
    if (eject == true)
    {
        [ejectMediaArr removeAllObjects];
        NSArray *mountedRemovableMedia = [[NSFileManager defaultManager] mountedVolumeURLsIncludingResourceValuesForKeys:nil options:NSVolumeEnumerationSkipHiddenVolumes];
        for(NSURL *volURL in mountedRemovableMedia)
        {
            int                 err = 0;
            DADiskRef           disk = NULL;
            CFDictionaryRef     descDict = NULL;
            DASessionRef session = DASessionCreate(NULL);
            if (session == NULL) {
                err = EINVAL;
            }
            if (err == 0) {
                disk = DADiskCreateFromVolumePath(NULL,session,(CFURLRef)volURL);
                if (session == NULL) {
                    err = EINVAL;
                }
            }
            if (err == 0) {
                descDict = DADiskCopyDescription(disk);
                if (descDict == NULL) {
                    err = EINVAL;
                }
            }
            if (err == 0) {
                CFTypeRef mediaEjectableKey = CFDictionaryGetValue(descDict,kDADiskDescriptionMediaEjectableKey);
                CFTypeRef deviceProtocolName = CFDictionaryGetValue(descDict,kDADiskDescriptionDeviceProtocolKey);
                if (mediaEjectableKey != NULL)
                {
                    BOOL op = CFEqual(mediaEjectableKey, CFSTR("0")) || CFEqual(deviceProtocolName, CFSTR("USB"));
                    if (op) {
                        [ejectMediaArr addObject:[NSString stringWithUTF8String:DADiskGetBSDName(disk)]];
        				DADiskUnmount(disk, kDADiskUnmountOptionForce, NULL, NULL);
                    }
                }
            }
            if (descDict != NULL) {
                CFRelease(descDict);
            }
            if (disk != NULL) {
                CFRelease(disk);
            }
            if (session != NULL) {
                CFRelease(session);
            }
        }
    }
    else
    {
        for(NSString* item in ejectMediaArr)   
        {
            DADiskRef disk = DADiskCreateFromBSDName(kCFAllocatorDefault, session, [item cStringUsingEncoding:NSUTF8StringEncoding]);
            DADiskMount(disk, NULL, DADiskGetOptions(disk), NULL, NULL);
        }
        [ejectMediaArr removeAllObjects];
    }
}


// Sleep/Wake event callback function, calls the fixup function
void SleepWakeCallBack( void * refCon, io_service_t service, natural_t messageType, void * messageArgument )
{
    switch ( messageType )
    {
        case kIOMessageCanSystemSleep:
            IOAllowPowerChange( root_port, (long)messageArgument );
            break;
        case kIOMessageSystemWillNotSleep:
            fixRtlWlan(@"0");
            ejectMedia(false);
            break;
        case kIOMessageSystemWillSleep:
            printf("Sleep fix.\n");
            setHibernationMode();
            ejectMedia(true);
            xhc2EjectStatus = ejectXHC2(true);
            //ThunderboltForcePower(false);
            fixRtlWlan(@"1");
            IOAllowPowerChange( root_port, (long)messageArgument );
            break;
        case kIOMessageSystemWillPowerOn:
            //ThunderboltForcePower(true);
            //rp01Probe(kIOPCIProbeOptionNeedsScan | kIOPCIProbeOptionDone);
            break;
        case kIOMessageSystemHasPoweredOn:
            printf("Wake fix.\n");
        	IONotificationPortDestroy(usbEjectNotifyPort);
            CFRunLoopStop(usbEjectRunLoop);
        	IONotificationPortDestroy(XHC2NotifyPort);
            CFRunLoopStop(XHC2RunLoop);
            pthread_create(&xhc2_id,NULL,(void*)XHC2WatcherThread,NULL);
            pthread_create(&usb_eject_id,NULL,(void*)UsbEjectWatcherThread,NULL);
            fixRtlWlan(@"0");
            if (!xhc2EjectStatus)
			    sleep(2);
            ejectMedia(false);
            break;
        default:
            break;
    }
}
// start cfrunloop that listen to wakeup event
void SleepWakeThread(void)
{
    IONotificationPortRef  notifyPortRef;
    void*                  refCon = NULL;
    root_port = IORegisterForSystemPower( refCon, &notifyPortRef, SleepWakeCallBack, &notifierObject );
    if ( root_port == 0 )
    {
        fprintf(stderr, "IORegisterForSystemPower failed\n");
        exit(1);
    }
    else
    {
        powerRunLoop = CFRunLoopGetCurrent();
        CFRunLoopAddSource( powerRunLoop,
            IONotificationPortGetRunLoopSource(notifyPortRef), kCFRunLoopCommonModes );
            printf("Starting sleep/wake watcher\n");
            CFRunLoopRun();
    }
}

int startDaemon() {
	
    // Set up error handler
    signal(SIGHUP, sigHandler);
    signal(SIGTERM, sigHandler);
    signal(SIGINT, sigHandler);
    signal(SIGKILL, sigHandler);
    signal(SIGTSTP, sigHandler);
    
    ejectMediaArr = [NSMutableArray array];
    session = DASessionCreate(NULL);
    
    //start a new thread that waits for wakeup event
    pthread_t sleep_wake_id;
    if (pthread_create(&sleep_wake_id,NULL,(void*)SleepWakeThread,NULL))
    {
        fprintf(stderr, "Error creating sleep/wake watcher thread!\n");
        return 1;
    }
    
    //start new threads that listens usb event
    if (pthread_create(&xhc2_id,NULL,(void*)XHC2WatcherThread,NULL))
    {
        fprintf(stderr, "Error creating xhc2 watcher thread!\n");
        return 1;
    }
    if (pthread_create(&usb_eject_id,NULL,(void*)UsbEjectWatcherThread,NULL))
    {
        fprintf(stderr, "Error creating usb eject watcher thread!\n");
        return 1;
    }
    
    
					   
    while(run)
        sleep(1);
    
    IODeregisterForSystemPower(&notifierObject);
    CFRunLoopStop(powerRunLoop);
	IONotificationPortDestroy(usbEjectNotifyPort);
    CFRunLoopStop(usbEjectRunLoop);
	IONotificationPortDestroy(XHC2NotifyPort);
    CFRunLoopStop(XHC2RunLoop);
    
    
    
    return 0;
}

int usage()
{
    
    fprintf(stderr, 
    "USBFix by maz-1\n"
    "usage:\n"
    "    daemon: start daemon\n"
    "    tbon: turn thunderbolt on\n"
    "    tboff: turn thunderbolt off\n"
    "    pwrhk <unsigned int>: set IOElectrify power hook\n"
    "        possible option: \n"
    "          0x0: disable both hooks\n"
    "          0x1: enable sleep hook\n"
    "          0x2: enable wake hook\n"
    "          0x3: enable both hooks\n"
    "    eject: eject xhc2\n"
    "    probe <unsigned int>: scan rp01 with given option\n"
    "        possible option: \n"
    "          0x0\n"
    "          0x80200000 (kIOPCIProbeOptionNeedsScan|kIOPCIProbeOptionDone)\n"
    "    unfreeze: unfreeze usb devices attached to XHC2\n"
    );
    return 1;
}

int main(int argc, const char * argv[]) {
    if (argc < 2)
        return usage();
	else if (!strcmp(argv[1], "tbon"))
		return ThunderboltForcePower(true);
	else if (!strcmp(argv[1], "tboff"))
		return ThunderboltForcePower(false);
	else if (!strcmp(argv[1], "pwrhk"))
    {
        if (argc > 2)
        {
            char *endptr;
            return IOElectrifyTogglePowerHook((uint32_t)strtol(argv[2], &endptr, 0));
        }
        else
            return IOElectrifyTogglePowerHook(0);
    }
	else if (!strcmp(argv[1], "eject"))
		return ejectXHC2(true);
	else if (!strcmp(argv[1], "probe"))
    {
        if (argc > 2)
        {
            char *endptr;
            return rp01Probe((uint32_t)strtol(argv[2], &endptr, 0));
        }
        else
            return rp01Probe(0);
    }
	else if (!strcmp(argv[argc-1], "daemon"))
		return startDaemon();
	else if (!strcmp(argv[argc-1], "unfreeze"))
        return unfreezeXHC2();
	else
		return usage();
    
    return 0;
}
