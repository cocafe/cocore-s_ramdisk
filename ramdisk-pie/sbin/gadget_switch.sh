#!/sbin/busybox sh

if [ -z $1 ]; then
  echo "usage: <gadeget_composite>"
  exit
fi

echo 0 			> /sys/class/android_usb/android0/enable
echo 0x6860 		> /sys/kernel/config/usb_gadget/g1/idProduct
echo 0x04E8 		> /sys/kernel/config/usb_gadget/g1/idVendor
echo $1		 	> /sys/class/android_usb/android0/functions
echo 0	 		> /sys/kernel/config/usb_gadget/g1/bDeviceClass
echo "10c00000.dwc3" 	> /sys/kernel/config/usb_gadget/g1/UDC
echo 1 			> /sys/class/android_usb/android0/enable

