#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "/attendedsysupgrade/d" {} +
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -exec sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" {} +
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -exec sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" {} +
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -exec sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" {} +

# 创建目录
mkdir -p ./package/base-files/files/etc/uci-defaults/

# 生成初始化配置文件
cat << EOF > ./package/base-files/files/etc/uci-defaults/99-custom-config
#!/bin/sh

# 统一执行所有 uci 配置，大幅提升首次开机处理速度
uci -q batch <<-UCI_EOF
	# ----------------- 1. WiFi 三频 SSID 名称与密码配置 -----------------
	# ===== Radio 0 (5G1) =====
	set wireless.radio0.disabled='0'
	set wireless.radio0.country='US'
	set wireless.radio0.channel='149'
	set wireless.radio0.htmode='HE80'
	set wireless.default_radio0.ssid='${WRT_SSID}'
	set wireless.default_radio0.encryption='psk2+ccmp'
	set wireless.default_radio0.key='${WRT_WORD}'

	# ===== Radio 1 (2.4G) =====
	set wireless.radio1.disabled='0'
	set wireless.radio1.country='US'
	set wireless.radio1.channel='1'
	set wireless.radio1.htmode='HE20'
	set wireless.default_radio1.ssid='${WRT_SSID}'
	set wireless.default_radio1.encryption='psk2+ccmp'
	set wireless.default_radio1.key='${WRT_WORD}'

	# ===== Radio 2 (5G2) =====
	set wireless.radio2.disabled='0'
	set wireless.radio2.country='US'
	set wireless.radio2.channel='44'
	set wireless.radio2.htmode='HE160'
	set wireless.default_radio2.ssid='${WRT_SSID}'
	set wireless.default_radio2.encryption='psk2+ccmp'
	set wireless.default_radio2.key='${WRT_WORD}'

	# ----------------- 2. IPv6 中继模式配置 -----------------
	# 清空 ULA 前缀
	set network.globals.ula_prefix=''

	# 配置 LAN 口为中继模式
	set dhcp.lan.ra='relay'
	set dhcp.lan.dhcpv6='relay'
	set dhcp.lan.ndp='relay'

	# 配置 WAN6 口为中继模式，并指定为主接口 (Master)
	set dhcp.wan6='dhcp'
	set dhcp.wan6.interface='wan6'
	set dhcp.wan6.master='1'
	set dhcp.wan6.ra='relay'
	set dhcp.wan6.dhcpv6='relay'
	set dhcp.wan6.ndp='relay'
UCI_EOF

# 统一提交更改
uci commit wireless
uci commit network
uci commit dhcp


# 赋予 athena-led 可执行权限
chmod +x /usr/sbin/athena-led
chmod +x /etc/init.d/athena_led
/etc/init.d/athena_led start


# uci-defaults 脚本会在首次启动完成后自动删除自己，返回 0 即可
exit 0
EOF

# 赋予可执行权限
chmod +x ./package/base-files/files/etc/uci-defaults/99-custom-config



CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
