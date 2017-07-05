<#
��cmake�ű������Զ������֪�����������
author: guyadong@gdface.net
#>
if(!$BUILD_VARS_INCLUDED){
. "$PSScriptRoot/build_funs.ps1"
}

# ���ı��ļ������������ʽ�����滻�ַ��������޸ĺ�����ݻ�д���ļ���
function regex_replace_file($text_file,$regex,$replace,$msg,[switch]$join){
    args_not_null_empty_undefined text_file regex 
    exit_if_not_exist $text_file -type Leaf 
    if( ! $msg ){
        $msg="modify $text_file"
    }
    $content=Get-Content $text_file
    if( $join ){
        $content=$content -join "`n"
    }
    $res=$content -match $regex
    if( $res){
        if($content -is [array]){
            [string[]]$lines=$res
        }else{
            [string[]]$lines=@($Matches[0])
        }
        Write-Host $msg -ForegroundColor Yellow
        $content -replace $regex,$replace| Out-File $text_file -Encoding ascii -Force 
        exit_on_error
        $lines | foreach{
            $_
            '====> '
            $_ -replace $regex,$replace
        }
    }
}
function disable_download_prebuilt_dependencies($cmakelists_root){
    args_not_null_empty_undefined cmakelists_root
    exit_if_not_exist $cmakelists_root -type Leaf 
    regex_replace_file -text_file $cmakelists_root `
                       -regex '(^\s*include\s*\(\s*cmake/WindowsDownloadPrebuiltDependencies\.cmake\s*\))' `
                       -replace "$sign#`$1" `
                       -msg "(��ֹ Windows Ԥ���������) disable download prebuilt dependencies ($cmakelists_root)" 
}

$regex_gtest_definitions="\n\s*if\s*\(\s*NOT\s+MSVC\s*\)(?:(\s|\s*#.*\n))*target_compile_definitions\s*\(\s*gtest\s+PUBLIC\s+-DGTEST_USE_OWN_TR1_TUPLE\s*\)(?:(\s|\s*#.*\n))*endif\s*\(\s*(NOT\s+MSVC)?\s*\)"

function remove_gtest_use_own_tr1_tuple($cmakelists){
    args_not_null_empty_undefined cmakelists
    exit_if_not_exist $cmakelists -type Leaf 
    $content=Get-Content $cmakelists
    if(($content -join "`n") -match $regex_gtest_definitions){
        Write-Host "(�ҵ���ȷ��GTEST_USE_OWN_TR1_TUPLE����)find GTEST_USE_OWN_TR1_TUPLE definition for gtest" -ForegroundColor Yellow
        return
    }
    $sign="#deleted by guyadong,remove GTEST_USE_OWN_TR1_TUPLE definition,do not edit it`n"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*add_definitions\s*\()\s*-DGTEST_USE_OWN_TR1_TUPLE\s*(\))' `
                        -replace "$sign#`$0`n" `
                        -msg "(ɾ��GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*add_definitions\s*\()(.*)-DGTEST_USE_OWN_TR1_TUPLE(.*)(\))' `
                        -replace "$sign`$1`$2`$3`$4" `
                        -msg "(ɾ��GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*target_compile_definitions\s*\(\s*\w+\s+)(?:(?:(?:INTERFACE|PUBLIC|PRIVATE)\s+)?-DGTEST_USE_OWN_TR1_TUPLE)\s*(\))' `
                        -replace "$sign#`$0" `
                        -msg "(ɾ��GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
    regex_replace_file  -text_file $cmakelists `
                        -regex '(^\s*target_compile_definitions\s*\(\s*\w+\s+)(.*?)(?:(?:(?:INTERFACE|PUBLIC|PRIVATE)\s+)?-DGTEST_USE_OWN_TR1_TUPLE)(.*)(\))' `
                        -replace "$sign#`$1`$2`$3`$4" `
                        -msg "(ɾ��GTEST_USE_OWN_TR1_TUPLE) remove GTEST_USE_OWN_TR1_TUPLE from add_definitions ($cmakelists)"
}

function add_gtest_use_own_tr1_tuple($cmakelists){
    args_not_null_empty_undefined cmakelists
    exit_if_not_exist $cmakelists -type Leaf 
    if((Get-Item $cmakelists).Directory.Name -ne 'gtest'){
        Write-Host "only CMakeLists.txt on 'gtest' folder" -ForegroundColor Yellow
        call_stack
        exit -1
    }
    $content=(Get-Content $cmakelists ) -join "`n"
    $sign="#added by guyadong,add GTEST_USE_OWN_TR1_TUPLE definition for gtest,do not edit it`n"    
    if( ! ($content -match $regex_gtest_definitions)){
        Write-Host "(����GTEST_USE_OWN_TR1_TUPLE����) add GTEST_USE_OWN_TR1_TUPLE for gtest ($cmakelists)" -ForegroundColor Yellow
        $content + "${sign}if(NOT MSVC)
  target_compile_definitions(gtest PUBLIC -DGTEST_USE_OWN_TR1_TUPLE)
endif(NOT MSVC)"| Out-File $cmakelists -Encoding ascii -Force
        exit_on_error
    }
}
# ɾ�������ļ��е� GTEST_USE_OWN_TR1_TUPLE ���壬�� gtest/CMakeLists.txt��Ϊ gtest ���� GTEST_USE_OWN_TR1_TUPLE ����
function modify_gtest_use_own_tr1_tuple($caffe_root){
    args_not_null_empty_undefined caffe_root
    ls $caffe_root -Filter 'CMakeLists.txt' | foreach {
        remove_gtest_use_own_tr1_tuple $_        
    }
    add_gtest_use_own_tr1_tuple [io.path]::Combine( $caffe_root,'src','gtest','CMakeLists.txt')
}

# �޸� set_caffe_link ���� MSVC ֧��
function modify_caffe_set_caffe_link($caffe_root){
    args_not_null_empty_undefined caffe_root
    $target_cmake=[io.path]::Combine($caffe_root,'cmake','Targets.cmake')
    exit_if_not_exist $target_cmake -type Leaf 
    $sign="`n#modified by guyadong,for build with msvc,do not edit it`n"    
    $set_caffe_link_body='  if(MSVC AND CMAKE_GENERATOR MATCHES Ninja)        
    foreach(_suffix "" ${CMAKE_CONFIGURATION_TYPES})
      if(NOT _suffix STREQUAL "")
        string(TOUPPER _${_suffix} _suffix)
      endif()
      set(CMAKE_CXX_FLAGS${_suffix} "${CMAKE_CXX_FLAGS${_suffix}} /FS")
      set(CMAKE_C_FLAGS${_suffix} "${CMAKE_C_FLAGS${_suffix}} /FS")              
    endforeach()
  endif()
  if(BUILD_SHARED_LIBS)
    set(Caffe_LINK caffe)
  else()
    if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
      set(Caffe_LINK -Wl,-force_load caffe)
    elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
      set(Caffe_LINK -Wl,--whole-archive caffe -Wl,--no-whole-archive)
    elseif(MSVC)
      set(Caffe_LINK caffe)
    endif()
  endif()'
    $regx_no_msvc='((?:(?!MSVC)[\s\S])*)'
    $regex_msvc='[\s\S]*'
    $regex_begin='(\n\s*macro\s*\(\s*caffe_set_caffe_link\s*\))'
    $regex_end='(endmacro\(\s*(?:caffe_set_caffe_link)?\s*\))'
    regex_replace_file  -text_file $target_cmake `
                        -regex ($regex_begin + $regx_no_msvc + $regex_end) `
                        -replace "`$1$sign$set_caffe_link_body`n`$3" `
                        -msg "(�޸�set_caffe_link)modify set_caffe_link for MSVC in $target_cmake " `
                        -join
    # ��ʾ�޸ĺ�Ľ��
    $null=((Get-Content $target_cmake) -join "`n") -match $regex_begin+$regex_msvc+$regex_end
    $Matches[0]
}
# �޸� cmake/ProtoBuf.cmake
function modify_protobuf_cmake($caffe_root){
    args_not_null_empty_undefined caffe_root
    $protobuf_cmake=[io.path]::Combine($caffe_root,'cmake','ProtoBuf.cmake')
    exit_if_not_exist $protobuf_cmake -type Leaf 
    $content=(Get-Content $protobuf_cmake) -join "`n"
    # ƥ�����ʽ:����ҵ� guyadong ��������޸Ĵ��� 
    $pattern='^((?:(?:\n\s*|\s*#(?:.{0})*\n))*)([^#\s].*\n[\s\S]+?)((?:(?:\s|\s*#.*\n))*if\s*\(\s*EXISTS\s+\$\s*\{\s*PROTOBUF_PROTOC_EXECUTABLE\s*\}\s*\))'
    if(! ($content -match $pattern.Replace('{0}','(?!guyadong)'))) {                    
        if($content -match $pattern.Replace('{0}','')){
            Write-Host "(�����޸�find protobuf package����)not need modify find protobuf package code in $protobuf_cmake"
            $Matches[2]
            return
        }else{
            Write-Host "(�������û��ƥ�䵽find protobuf package����)not found find package for protobuf code by regular expression in $protobuf_cmake"
            call_stack
            exit -1
        }
    }
    $find_package_block=$Matches
    $hdf5_include_dir=($find_package_block[2] -split "`n") -match '(list|include_directories)\s*\(.*PROTOBUF_INCLUDE_DIR.*\)'
    $protobuf_libraries=($find_package_block[2] -split "`n") -match 'list\s*\(.*PROTOBUF_LIBRARIES.*\)'
    if(!$hdf5_include_dir -or !$protobuf_libraries){
        Write-Host "(�������û��ƥ�䵽 PROTOBUF_INCLUDE_DIR PROTOBUF_LIBRARIES ��ֵ����)not found PROTOBUF_INCLUDE_DIR PROTOBUF_LIBRARIES assing statement by regular expression in $protobuf_cmake"
        call_stack
        exit -1
    }
    $sign="# modified by guyadong`n# search using protobuf-config.cmake"
    $find_package_block[2]="$sign`nfind_package( Protobuf REQUIRED NO_MODULE)`nset(PROTOBUF_INCLUDE_DIR `${PROTOBUF_INCLUDE_DIRS})`n$($hdf5_include_dir.trim())`n$($protobuf_libraries.trim())"
    Write-Host "(�޸� protobuf ������) modify profobuf find package $protobuf_cmake"
    $content.Replace($find_package_block[0],($find_package_block[1..3] -join "`n")) -split "`n" | Out-File $protobuf_cmake -Encoding ascii -Force
    $find_package_block[2]
}
# �޸� VS2013����ʱ�� boost 
function support_boost_vs2013($caffe_root){    
    args_not_null_empty_undefined caffe_root
    $dependencies_cmake= [io.path]::combine( $caffe_root,'cmake','Dependencies.cmake')
    exit_if_not_exist $dependencies_cmake -type Leaf 
    $regex_code='\s*if\s*\(\s*(?:(?:DEFINED\s+)?)MSVC\s+AND\s+CMAKE_CXX_COMPILER_VERSION VERSION_LESS\s+18.0.40629.0\s*\)((?:(?:\n\s*|\s*#.*\n))*)\s*add_definitions\s*\(\s*-DBOOST_NO_CXX11_TEMPLATE_ALIASES\s*\)\s*endif\(.*\)'
    $content=(Get-Content $dependencies_cmake) -join "`n"
    if( $content -match $regex_code){
        Write-Host "(�����޸�) BOOST_NO_CXX11_TEMPLATE_ALIASES definition is present, $dependencies_cmake"
        $Matches[0]
        return
    }
    $regex_boost_block='(#\s*---\[\s*Boost.*\n)([\s\S]+)(#\s*---\[\s*Threads)'
    $patch_code='if( MSVC AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS 18.0.40629.0)
  # Required for VS 2013 Update 4 or earlier.
  add_definitions(-DBOOST_NO_CXX11_TEMPLATE_ALIASES)
endif()
'
    if( !($content -match $regex_boost_block)){
        Write-Host "����:(û��ƥ�䵽find boost package��ش���) warning:not match code for finding  boost package regular expression in $dependencies_cmake" -ForegroundColor Yellow
        Write-Host "������'# ---[ Boost' �� '# ---[ Threads' Ϊ��ǲ���findg boost package��صĴ������ʵ�ִ����Զ����¡�
���û���ҵ���������ǣ��޷�����Զ�����,���ֹ������´��븴�Ƶ� $dependencies_cmake 
���������Visual Studio 2013���룬���Ժ��Դ˾���.
�����Visual Studio 2013���룬�뽫���´������ӵ� $dependencies_cmake ��ʼ��λ��,�������ᱨ����
$patch_code
"
    }
    regex_replace_file -text_file $dependencies_cmake `
                        -regex $regex_boost_block `
                        -replace "`$1`$2#modified by guyadong`n$patch_code`$3" `
                        -msg "(���Ӷ�VS2103��boost����֧�ִ���)add BOOST_NO_CXX11_TEMPLATE_ALIASES definition in $dependencies_cmake" `
                        -join
    # ��ʾ�޸ĺ�Ľ��
    $null=((Get-Content $dependencies_cmake) -join "`n") -match $regex_code
    $Matches[0]
}
# �޸� cmake/Dependencies.cmake ������hdf5����
function modify_find_hdf5($caffe_root){
    args_not_null_empty_undefined caffe_root
    $dependencies_cmake= [io.path]::combine( $caffe_root,'cmake','Dependencies.cmake')
    exit_if_not_exist $dependencies_cmake -type Leaf 
    $content=(Get-Content $dependencies_cmake) -join "`n"
    # ƥ�����ʽ:����ҵ� guyadong ��������޸Ĵ��� 
    $pattern='(\s*#\s*---\s*\[\s*HDF5.*\n)((?:(?:\n\s*|\s*#(?:.{0})*\n))*[^#\s].*\n[\s\S]+?)(#\s*---\s*\[\s*LMDB)'
    if( !($content -match $pattern.Replace('{0}','(?!guyadong)'))) {
        if($content -match $pattern.Replace('{0}','')){
            Write-Host "(�����޸�find_package����)not need modify find_package code in $dependencies_cmake"
            $Matches[2]
            return
        }else{
            Write-Host "(�������û��ƥ�䵽find hdf5 package����)not found find_package code for hdf5 by regular expression in $dependencies_cmake"
            Write-Host "������'# ---[ HDF5' �� '# ---[ LMDB' Ϊ��ǲ���findg hdf5 package��صĴ������ʵ�ִ����Զ����¡����û���ҵ���������ǣ��޷�����Զ�����"
            call_stack
            exit -1
        }
    }
    $find_package_block=$Matches
    $hdf5_include_dir=($find_package_block[2] -split "`n") -match '(list|include_directories)\s*\(.*HDF5_INCLUDE_DIRS.*\)'
    $hdf5_libraries=($find_package_block[2] -split "`n") -match 'list\s*\(.*HDF5_LIBRARIES.*\)'
    if(!($hdf5_libraries -match 'HDF5_HL_LIBRARIES')){
        $hdf5_libraries=$hdf5_libraries -replace '\$\s*\{\s*HDF5_LIBRARIES\s*\}','$0 ${HDF5_HL_LIBRARIES}'
    }
    if(!$hdf5_include_dir -or !$hdf5_libraries){
        Write-Host "(�������û��ƥ�䵽 HDF5_INCLUDE_DIRS HDF5_LIBRARIES ��ֵ����)not found HDF5_INCLUDE_DIRS HDF5_LIBRARIES assing statement by regular expression in $dependencies_cmake"
        call_stack
        exit -1
    }
    $sign="# modified by guyadong`n# Find HDF5 always using static libraries"
    $find_package_block[2]="$sign`nfind_package(HDF5 COMPONENTS C HL REQUIRED)`nset(HDF5_LIBRARIES hdf5-static)`nset(HDF5_HL_LIBRARIES hdf5_hl-static)`n$($hdf5_include_dir.trim())`n$($hdf5_libraries.trim())"
    Write-Host "(�޸� hdf5 ������) modify find package for hdf5,$dependencies_cmake"
    $content.Replace($find_package_block[0],($find_package_block[1..3] -join "`n")) -split "`n" | Out-File $dependencies_cmake -Encoding ascii -Force
    $find_package_block[2]
}
# �޸� /src/caffe/CMakeLists.txt /tools/CMakeLists.txt�п��ܴ��ڵ�����
function modify_src_cmake_list($caffe_root){
    args_not_null_empty_undefined caffe_root
    $src_caffe_cmake= [io.path]::combine( $caffe_root,'src','caffe','CMakeLists.txt')
    regex_replace_file  -text_file $src_caffe_cmake `
                        -regex '(^\s*target_link_libraries\(caffe\s+)(?!PUBLIC\s+)(.*\$\{Caffe_LINKER_LIBS\}\))' `
                        -replace '$1PUBLIC $2' `
                        -msg "(����tools��target û�����ӿ������),add PUBLIC keyword $src_caffe_cmake"
    $tools_cmake=[io.path]::combine( $caffe_root,'tools','CMakeLists.txt')
    regex_replace_file  -text_file $tools_cmake `
                        -regex '(^\s*target_link_libraries\s*\(\s*\$\{\s*name\s*\}\s+\$\s*\{\s*Caffe_LINK\s*\}(?:(?!\s+\$\{\s*Caffe_LINKER_LIBS\s*\}).)*)(\s*\))' `
                        -replace '$1 ${Caffe_LINKER_LIBS} $2' `
                        -msg "(����tools��target û�����ӿ������)��add dependencies libraries for executable targets in tools $tools_cmake"
}
# ���� caffe ��Ŀ����ͨ�ò�������, 
# ���� caffe ϵ����Ŀfetch�� Ӧ�ȵ��ô˺������޲�
# $caffe_root caffe Դ���Ŀ¼
function modify_caffe_general([string]$caffe_root){
    args_not_null_empty_undefined caffe_root
    exit_if_not_exist $caffe_root -type Container
    # ͨ���ǲ�����src/caffe �ļ����ж��ǲ��� caffe ��Ŀ
    exit_if_not_exist ([io.path]::Combine($caffe_root,'src','caffe')) -type Container -msg "$caffe_root �����Ǹ� caffe Դ���ļ���"

}

#remove_gtest_use_own_tr1_tuple('D:\caffe-ssd-win32\CMakeLists.txt')
#add_gtest_use_own_tr1_tuple('D:\caffe-ssd-win32\src\gtest\CMakeLists.txt')
#remove_gtest_use_own_tr1_tuple('D:\caffe-ssd-win32\src\gtest\CMakeLists.txt')
#modify_caffe_set_caffe_link D:\caffe-ssd-win32
#modify_protobuf_cmake D:\caffe-ssd-win32
#support_boost_vs2013 D:\caffe-ssd-win32
#modify_find_hdf5 D:\caffe-ssd-win32
#modify_src_cmake_list D:\caffe-ssd-win32