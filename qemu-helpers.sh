# qemu alias
#alias qemu='qemu-system-x86_64 -accel kvm -machine q35 -m 3072 -device VGA,edid=on,xres=1280,yres=720 -device qemu-xhci -device usb-tablet -serial mon:stdio'

# qemu command line helper (function)
# use configuration file if exists AND executable
# otherwise call qemu with defined/prefered parameters
# additional parameters (override) are forwarded in both cases
# (use #!/usr/bin/false as shebang in configuration file to avoid execution)
qemu() {
    TMPDIR=/tmp/
    config=.4qemu
    qemu=qemu-system-x86_64
    echo "qemu command line helper :"
    if [ -s "$config" ] && [ -x "$config" ]
    then
        echo "running $qemu" $( grep -v '#.*' "$config" | tr '\n' ' ' )
        "$qemu" $( grep -v '#.*' "$config" ) $@
    else
        echo "running $qemu with defined parameters"
        "$qemu" \
        -accel kvm \
        -machine q35 -m 2048 \
        -cpu qemu64,sse4.2,popcnt,kvm=off -smp 2 \
        -device qemu-xhci -device usb-tablet \
        -parallel null -serial mon:stdio \
        $@
    fi
}

# qemu-img create helper (bash function)
# no need to specify backing file format (auto-detected)
# and/or desired file format (qcow2 by default)
qemu-img () {
    local verb=$1
    shift
    local base baseFormat format
    [[ "$verb" == "create" ]] &&
    {
        local opt OPTARG OPTIND
        while getopts 'b:F:f:' opt
        do
            case $opt in
                b) base=$OPTARG;;
                F) baseFormat=$OPTARG;;
                f) format=$OPTARG;;
            esac
        done
        shift $((OPTIND-1))
        [[ "$base" ]] &&
        {
            [[ ! -e "$base" ]] && echo 'Base image: no such file or directory' >/dev/stderr && return 1
            [[ ! -r "$base" ]] && echo 'Base image: no read permission' >/dev/stderr && return 1
            [[ -w "$base" ]] && echo 'Base image: base image is writable' >/dev/stderr && return 1
            [[ "$baseFormat" ]] || baseFormat=$( [[ "$( head -c4 "$base" | base64 )" == "UUZJ+w==" ]] && echo qcow2 || echo raw )
            [[ "$format" ]] || format='qcow2'
        }
    }
    /usr/bin/qemu-img "$verb" -b "$base" -F "$baseFormat" -f "$format" $@
}

# qemu USB helper (bash function)
qemu-usbhost() {
    for usb in $( find /sys/bus/usb/devices/ | grep -E '/[0-9]+-[0-9]+$' )
    do
        cat $usb/product 2>/dev/null || echo "unknown device"
        busport=$( basename $usb )
        echo $(
            sed -e 's/-/,hostport=/' \
                -e 's/^/device_add usb-host,hostbus=/' \
                -e 's/$/,id=usb-host-'$busport/ <<< $busport
        )
        read vendor < $usb/idVendor
        read product < $usb/idProduct
        echo device_add usb-host,vendorid=0x$vendor,productid=0x$product,id=usb-host-$vendor-$product
        echo
    done | tr '[:upper:]' '[:lower:]'
}
