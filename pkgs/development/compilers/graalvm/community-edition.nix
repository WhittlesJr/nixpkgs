{ lib, stdenv, fetchurl, perl, unzip, glibc, zlib, setJavaClassPath }:

let
  common = javaVersion:
    let
      graalvmXXX-ce = stdenv.mkDerivation rec {
        pname = "graalvm${javaVersion}-ce";
        version = "21.0.0";
        srcs = [
          (fetchurl {
             sha256 = {  "8" = "18q1plrpclp02rlwn3vvv2fcyspvqv2gkzn14f0b59pnladmlv1j";
                        "11" = "1g1xjbr693rimdy2cy6jvz4vgnbnw76wa87xcmaszka206fmpnsc";
                      }.${javaVersion};
             url    = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/graalvm-ce-java${javaVersion}-linux-amd64-${version}.tar.gz";
          })
          (fetchurl {
             sha256 = {  "8" = "0hpq2g9hc8b7j4d8a08kq1mnl6pl7a4kwaj0a3gka3d4m6r7cscg";
                        "11" = "0z3hb2bf0lqzw760civ3h1wvx22a75n7baxc0l2i9h5wxas002y7";
                      }.${javaVersion};
             url    = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/native-image-installable-svm-java${javaVersion}-linux-amd64-${version}.jar";
          })
          (fetchurl {
             sha256 = {  "8" = "122p8psgmzhqnjb2fy1lwghg0kw5qa8xkzgyjp682lwg4j8brz43";
                        "11" = "1vdc90m6s013cbhmj58nb4vyxllbxirw0idlgv0iv9cyhx90hzgz";
                      }.${javaVersion};
             url    = "https://github.com/oracle/truffleruby/releases/download/vm-${version}/ruby-installable-svm-java${javaVersion}-linux-amd64-${version}.jar";
          })
          (fetchurl {
             sha256 = {  "8" = "19m7n4f5jrmsfvgv903sarkcjh55l0nlnw99lvjlcafw5hqzyb91";
                        "11" = "18ibb7l7b4hmbnvyr8j7mrs11mvlsf2j0c8rdd2s93x2114f26ba";
                      }.${javaVersion};
             url    = "https://github.com/graalvm/graalpython/releases/download/vm-${version}/python-installable-svm-java${javaVersion}-linux-amd64-${version}.jar";
          })
          (fetchurl {
             sha256 = {  "8" = "0dlgbg6kri89r9zbk6n0ch3g8356j1g35bwjng87c2y5y0vcw0b5";
                        "11" = "1yby65hww6zmd2g5pjwbq5pv3iv4gfv060b8fq75fjhwrisyj5gd";
                      }.${javaVersion};
             url    = "https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${version}/wasm-installable-svm-java${javaVersion}-linux-amd64-${version}.jar";
          })
        ];
        nativeBuildInputs = [ unzip perl ];
        unpackPhase = ''
           unpack_jar() {
             jar=$1
             unzip -o $jar -d $out
             perl -ne 'use File::Path qw(make_path);
                       use File::Basename qw(dirname);
                       if (/^(.+) = (.+)$/) {
                         make_path dirname("$ENV{out}/$1");
                         system "ln -s $2 $ENV{out}/$1";
                       }' $out/META-INF/symlinks
             perl -ne 'if (/^(.+) = ([r-])([w-])([x-])([r-])([w-])([x-])([r-])([w-])([x-])$/) {
                         my $mode = ($2 eq 'r' ? 0400 : 0) + ($3 eq 'w' ? 0200 : 0) + ($4  eq 'x' ? 0100 : 0) +
                                    ($5 eq 'r' ? 0040 : 0) + ($6 eq 'w' ? 0020 : 0) + ($7  eq 'x' ? 0010 : 0) +
                                    ($8 eq 'r' ? 0004 : 0) + ($9 eq 'w' ? 0002 : 0) + ($10 eq 'x' ? 0001 : 0);
                         chmod $mode, "$ENV{out}/$1";
                       }' $out/META-INF/permissions
             rm -rf $out/META-INF
           }

           mkdir -p $out
           arr=($srcs)
           tar xf ''${arr[0]} -C $out --strip-components=1
           unpack_jar ''${arr[1]}
           unpack_jar ''${arr[2]}
           unpack_jar ''${arr[3]}
           unpack_jar ''${arr[4]}
        '';

        installPhase = {
          "8" = ''
            # BUG workaround http://mail.openjdk.java.net/pipermail/graal-dev/2017-December/005141.html
            substituteInPlace $out/jre/lib/security/java.security \
              --replace file:/dev/random    file:/dev/./urandom \
              --replace NativePRNGBlocking  SHA1PRNG

            # provide libraries needed for static compilation
            for f in ${glibc}/lib/* ${glibc.static}/lib/* ${zlib.static}/lib/*; do
              ln -s $f $out/jre/lib/svm/clibraries/linux-amd64/$(basename $f)
            done

            # allow using external truffle-api.jar and languages not included in the distrubution
            rm $out/jre/lib/jvmci/parentClassLoader.classpath
          '';
          "11" = ''
            # BUG workaround http://mail.openjdk.java.net/pipermail/graal-dev/2017-December/005141.html
            substituteInPlace $out/conf/security/java.security \
              --replace file:/dev/random    file:/dev/./urandom \
              --replace NativePRNGBlocking  SHA1PRNG

            # provide libraries needed for static compilation
            for f in ${glibc}/lib/* ${glibc.static}/lib/* ${zlib.static}/lib/*; do
              ln -s $f $out/lib/svm/clibraries/linux-amd64/$(basename $f)
            done
           '';
        }.${javaVersion};

        dontStrip = true;

        # copy-paste openjdk's preFixup
        preFixup = ''
          # Set JAVA_HOME automatically.
          mkdir -p $out/nix-support
          cat <<EOF > $out/nix-support/setup-hook
            if [ -z "\''${JAVA_HOME-}" ]; then export JAVA_HOME=$out; fi
          EOF
        '';

        postFixup = ''
          rpath="${ {  "8" = "$out/jre/lib/amd64/jli:$out/jre/lib/amd64/server:$out/jre/lib/amd64";
                      "11" = "$out/lib/jli:$out/lib/server:$out/lib";
                    }.${javaVersion}
                 }:${
            lib.makeLibraryPath [
              stdenv.cc.cc.lib # libstdc++.so.6
              zlib             # libz.so.1
            ]}"

          for f in $(find $out -type f -perm -0100); do
            patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" "$f" || true
            patchelf --set-rpath   "$rpath"                                    "$f" || true

            if ldd "$f" | fgrep 'not found'; then echo "in file $f"; fi
          done
        '';

        propagatedBuildInputs = [ setJavaClassPath zlib ]; # $out/bin/native-image needs zlib to build native executables

        doInstallCheck = true;
        installCheckPhase = ''
          echo ${lib.escapeShellArg ''
                   public class HelloWorld {
                     public static void main(String[] args) {
                       System.out.println("Hello World");
                     }
                   }
                 ''} > HelloWorld.java
          $out/bin/javac HelloWorld.java

          # run on JVM with Graal Compiler
          $out/bin/java -XX:+UnlockExperimentalVMOptions -XX:+EnableJVMCI -XX:+UseJVMCICompiler HelloWorld | fgrep 'Hello World'

          # Ahead-Of-Time compilation
          $out/bin/native-image --no-server HelloWorld
          ./helloworld | fgrep 'Hello World'

          # Ahead-Of-Time compilation with --static
          $out/bin/native-image --no-server --static HelloWorld
          ./helloworld | fgrep 'Hello World'
        '';

        passthru.home = graalvmXXX-ce;

        meta = with lib; {
          homepage = "https://www.graalvm.org/";
          description = "High-Performance Polyglot VM";
          license = with licenses; [ upl gpl2Classpath bsd3 ];
          maintainers = with maintainers; [ bandresen volth hlolli glittershark ];
          platforms = [ "x86_64-linux" ];
        };
      };
    in
      graalvmXXX-ce;
in {
  graalvm8-ce  = common  "8";
  graalvm11-ce = common "11";
}
