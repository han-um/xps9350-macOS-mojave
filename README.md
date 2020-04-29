# xps9350-macOS-mojave
기존 [hackintosh-stuff](https://github.com/hackintosh-stuff/XPS9350-macOS)의 가이드에서 비정상적으로 긴 로딩, 일부 불안정한 설치 등을 마구잡이로 해결하였습니다.

## 주의사항
* 저는 해킨토시에 대해 잘 알지 못하는 초보자입니다. 
* 따라서 이 파일들은 완전하지 않거나, 비효율적이거나, 문제를 일으킬 수 있습니다.
* 그저 같은 사양의 XPS 13 9350 사용자들이 덜 고생하도록 세팅을 공유하는것이 목적입니다.
* 이런 이유로 설치 시 일어나는 오류나 이슈에 대해서는 답변하지 못하고, 답변하지 않을 예정입니다.

## Caution
* I'm a absolute beginner with hackintosh
* So, these files may be incomplete, inefficient, or may cause problems.
* I just want to share the settings with XPS 13 9350 users of the same specifications.
* I will not be able to answer any errors or issues that occur during the installation.

## Simple Instruction (in English)
* Install MojaveInstaller, Clover Bootloader to USB Drive (in VMWare or Your Own mac)
* Mount EFI Partition, and Overwrite xps9350-macOS-mojave/CLOVER to /EFI/CLOVER
* You need to Export ACPI
  * in Clover Bootloader, Press F4 (or Fn+F4) to Export ACPI files
  * Boot your own Mac (or Use PartitionWizard + Explorer++ to Mount EFI Partition)
  * go to /EFI/CLOVER/ACPI/Origin, Copy it, and Overwrite into /EFI/CLOVER/ACPI/Patched

## 사양
* 하드웨어
  - 모델 : XPS 13 9350
  - CPU : i5-6200U
  - RAM : 8GB
  - WLAN : DW1830 (기존 DW1820A에서 교체)
  - SSD : Samsung PM951 256GB
  - DP : QHD+
* 소프트웨어
  - BIOS : 1.10.1
  - OS : 10.14.6 (Mojave)
  - Clover : 2.5k 5033

## 동작하지 않는것
* SD카드 리더
* 트랙패드의 복잡한 제스쳐 (Elan kext를 사용하라는 조언은 있는데 부팅실패)
* USB-C포트 (단, 충전은 가능)

## 설치
### 0. WLAN 카드 교환 혹은 제거
* 기본으로 제공되는 DW1820A를 사용하고 있다면, 후판을 열어 랜카드를 제거해야만 부팅이 가능합니다.
  * DW1820A를 인식시키는 방법도 있지만, 세부모델에 따라 복불복이라고 합니다. 여기서는 다루지 않습니다.
* 가능하다면 DW1830으로 교체하세요. DW1560도 바로 인식이 가능한 세팅이지만 확인해보지 않았습니다.

### 1. BIOS 세팅
* TPM - Disabled
* SATA Operation - AHCI
* Secure Boot - Disabled
* Virtualization - OFF ( VTd I/O - OFF )

### 2. 설치 USB 만들기
* 순정 맥의 설치USB를 만들면 됩니다. 가이드는 직접 찾아보시면 쉽게 설명한 글이 많습니다.
* 간단하게는 아래와 같습니다.
  * VM웨어에 osx설치, 혹은 리얼맥 사용
  * AppStore에서 Mojave installer 설치
  * Terminal 혹은 install disk creator로 설치 USB만들기
* 설치된 USB에 Clover를 설치합니다.
  * 설치중 사용자화 를 눌러 옵션은 UEFI와 ESP, UEFI 드라이버만 체크하시면 됩니다.
  * 설치중 설치 위치 변경... 을 눌러 USB에 설치해야 합니다.
* USB의 EFI영역의 EFI/CLOVER를 첨부된 CLOVER 폴더로 대체합니다.
  * 맥의 대치와 병합이 익숙하지 않은 분들은 확실하게 원본 CLOVER를 삭제하고, 옮기시는걸 추천합니다.
  
### 2-1. ACPI 추출하기 (2020.04 Updated)
* 전원을 넣고 F12를 눌러 USB로 부팅합니다.
  * 가끔 USB가 목록에 뜨지 않으면 F2를 눌러 Boot Sequence에서 수동으로 BOOTX64.efi를 잡아줘야합니다.
* clover 부트 선택지가 나타나면 F4 (혹은 Fn+F4) 를 누릅니다.
* clover를 종료합니다.
* VM웨어의 MacOS 혹은 Windows의 PartitionWizard + Explorer++를 통해 USB의 EFI영역을 마운트합니다.
* EFI/CLOVER/ACPI/origin 폴더의 내용을 /ACPI/Patched에 덮어씌웁니다.

### 3. OS설치
* 전원을 넣고 F12를 눌러 USB로 부팅합니다.
* Mojave installer 로 부팅하여 설치를 진행합니다.
* 디스크 유틸리티를 이용합니다.
  * 표시되는 창의 우측상단의 아이콘을 눌러 모든 기기 보기로 바꿉니다.
  * SSD이름이 표시되면 클릭 후, 지우기 버튼을 클릭합니다.
  * APFS / GUID 형식으로 포맷합니다.
  * x를 눌러 설치 화면으로 나옵니다.
* Mac OS를 설치합니다.
  * 설치 도중 재부팅되면, 다시 F12를 눌러 USB의 클로버로 부팅합니다.
  * 클로버에 못보던 MacOS install이라는 선택지가 생겼을겁니다. 이것을 선택합니다.
  * 이후 설치 진행중 재부팅될때마다 위의 과정을 반복하시면 됩니다.

## 4. Post-install
* 설치 후 일부 기능이 동작하지 않을 수 있습니다. 대표적으로 잠자기와 스피드스탭 등입니다.
* 첨부된 post-install.command를 실행하여 명령에 따릅니다. xcode를 설치해야 합니다.
* (2020.04 Updated) 해당 파일을 실행할 경우, Clover 부트로더가 깨져 진입이 불가능할 수 있습니다.
  * 이럴 경우, USB를 통해 다시 부팅하여 이 Repo의 /CLOVER를 다시 SSD의 EFI파티션에 덮어씌우면 됩니다.
  * 해당 과정을 아예 진행하지 않을 경우, 스피드스탭이 동작하지 않습니다.

## 5. Clover 설치
* 이번에는 설치한 SSD에 클로버 부트로더를 설치합니다.
* SSD의 EFI영역의 EFI/CLOVER를 첨부된 CLOVER폴더로 대체합니다.
* 이제 USB가 없어도 클로버로 부팅할 수 있습니다. USB는 비상용으로 초기화하지않고 보관하는것이 좋습니다.

## 6. 기능 확인
* SpeedStep은 CPU클럭을 동적으로 조절하는 기능입니다. MSRDumper로 확인하면 됩니다. 잘 모르겠으면 확실한 방법은 아니지만 Intel Power Gadget을 설치한 후 Idle상태에서 0.5~1.0Ghz사이의 클럭을 유지하는지, 여러 작업을 할 경우 2.7Ghz까지 올라가는지만 체크하셔도 됩니다.
* Sleep은 상단 애플 아이콘에서 잠자기..를 누르거나 화면을 덮었다가 열었을때 화면이 잠기는지 체크하시면 됩니다.
* 그외 이어폰 소리, wifi연결, 블루투스 연결, 터치패드 및 키보드 동작을 체크하시면 됩니다.

## 7. SMBIOS설정
* 현재 config.plist의 SMBIOS Serial은 00000000으로 되어있습니다. 이 상태에서는 icloud/imessage 사용이 불가능합니다.
* 임의의 키를 만들고 SMBIOS를 세팅하고 아이메시지를 활성화하는것은 다른 가이드를 찾아보세요.



## Credits
> https://github.com/hackintosh-stuff/XPS9350-macOS <br />
 https://github.com/tlefko/macOS-Mojave-XPS13-9350 <br />
 https://www.insanelymac.com/forum/topic/335390-macos-mojave-xps-13-guide-support/<br />
https://github.com/syscl/XPS9350-macOS
