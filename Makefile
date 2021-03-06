GENDARME_URL = https://cloud.github.com/downloads/spouliot/gendarme/gendarme-2.10-bin.zip
VK_XML_URL = https://raw.githubusercontent.com/KhronosGroup/Vulkan-Docs/1.0/src/spec/vk.xml

CONFIGURATION = Debug
BIN_PATH = bin/$(CONFIGURATION)
BIN_PATH_RELEASE = bin/Release

all: $(BIN_PATH)/vk.xml $(BIN_PATH)/Vulkan.dll

$(BIN_PATH)/vk.xml:
	msbuild /t:DownloadSpecification src/Vulkan/Vulkan.csproj
	mkdir -p $(BIN_PATH_RELEASE)
	cp "$@" $(BIN_PATH_RELEASE)

$(BIN_PATH)/Vulkan.dll: $(wildcard src/Vulkan/*.cs src/Vulkan/*/*.cs tools/Generator/*cs)
	msbuild /p:Configuration=$(CONFIGURATION)

clean:
	rm -Rf $(BIN_PATH)
	rm -Rf $(BIN_PATH_RELEASE)
	rm -rf netstandard/bin netstandard/obj

fxcop: lib/gendarme-2.10/gendarme.exe
	mono --debug $< --html $(BIN_PATH)/gendarme.html \
		$(if @(GENDARME_XML),--xml $(BIN_PATH)/gendarme.xml) \
		--ignore gendarme-ignore.txt \
		$(BIN_PATH)/Vulkan.dll

lib/gendarme-2.10/gendarme.exe:
	-mkdir -p `dirname "$@"`
	curl -o lib/gendarme-2.10/gendarme-2.10-bin.zip $(GENDARME_URL)
	(cd lib/gendarme-2.10 ; unzip gendarme-2.10-bin.zip)

update-docs: $(BIN_PATH)/Vulkan.dll
	cp /Library/Frameworks/Mono.framework/Versions/Current/lib/mono/4.5/Facades/System.Runtime.dll .
	cp /Library/Frameworks/Mono.framework/Versions/Current/lib/mono/4.5/Facades/System.Collections.dll .
	mdoc update --out=docs/en $(BIN_PATH)/Vulkan.dll
	mdoc export-msxdoc docs/en/ --out docs/Vulkan.xml
	mdoc export-html docs/en/ --out docs/html

assemble-docs:
	mdoc assemble --out=docs/Vulkan docs/en

run-android-samples:
	msbuild /t:Install\;_Run samples/Inspector/Inspector.csproj
	msbuild /t:Install\;_Run samples/ClearView/ClearView.csproj
	msbuild /t:Install\;_Run samples/XLogo/XLogo.csproj

nuget: all netstandard-vulkansharp
	nuget pack

run-tests:
	$(MAKE) -C tests/NativeMemory clean deploy run

netstandard-vulkansharp: netstandard/Vulkan.csproj netstandard/obj/obj/project.assets.json
	msbuild $<

netstandard/obj/obj/project.assets.json: netstandard/Vulkan.csproj
	nuget restore $<

API_ASSEMBLIES=\
	bin/$(CONFIGURATION)/Vulkan.dll \
	src/Platforms/Android/bin/$(CONFIGURATION)/Vulkan.Android.dll \
	src/Platforms/Windows/bin/$(CONFIGURATION)/Vulkan.Windows.dll

api-update:
	mkdir -p api-info
	mono-api-info --ignore-resolution-errors $(API_ASSEMBLIES) > api-info/reference.xml

api-check:
	mono-api-info --ignore-resolution-errors $(API_ASSEMBLIES) > current-api.xml
	mono-api-html api-info/reference.xml current-api.xml > api-changes.html
