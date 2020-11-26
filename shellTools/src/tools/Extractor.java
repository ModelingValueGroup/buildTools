//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// (C) Copyright 2018-2020 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
//                                                                                                                     ~
// Licensed under the GNU Lesser General Public License v3.0 (the 'License'). You may not use this file except in      ~
// compliance with the License. You may obtain a copy of the License at: https://choosealicense.com/licenses/lgpl-3.0  ~
// Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on ~
// an 'AS IS' BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the  ~
// specific language governing permissions and limitations under the License.                                          ~
//                                                                                                                     ~
// Maintainers:                                                                                                        ~
//     Wim Bast, Tom Brus, Ronald Krijgsheld                                                                           ~
// Contributors:                                                                                                       ~
//     Arjan Kok, Carel Bast                                                                                           ~
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

package tools;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.Map.*;
import java.util.function.*;
import java.util.stream.*;
import java.util.zip.*;

public class Extractor {
    private static final String CP_SEP     = System.getProperty("path.separator");
    private static final String CLASS_PATH = System.getProperty("java.class.path", ".");
    private static final String HASH_BANG  = "#!/usr/bin/env bash";
    private static final String SH_EXT     = ".sh";
    private static final String UNFINISHED = "unfinished";
    private static final Path   MEME       = Paths.get("buildtoolsMeme.sh");
    private static final Path   PROJECT    = Paths.get("project.sh");

    public static void main(final String[] args) {
        for (String arg : args) {
            if (arg.startsWith("-check")) {
                if (arg.startsWith("-check=")) {
                    checkMeme(Paths.get(arg.replaceFirst("^-check=", "")));
                } else {
                    checkMeme();
                }
                System.exit(0);
            }
            if (arg.equals("-version")) {
                showVersion();
                System.exit(0);
            }
            if (arg.equals("-meme")) {
                getMemeLines().forEach(System.out::println);
                System.exit(0);
            }
        }

        Path ourClassPathElement = whereInClassPath(getMyPath()).orElseThrow();

        List<String> lines = walk(ourClassPathElement)
                .filter(p -> p.getFileName().toString().endsWith(SH_EXT))
                .filter(p -> !p.startsWith(UNFINISHED))
                .filter(p -> !p.equals(MEME))
                .filter(p -> !p.equals(PROJECT))
                .sorted()
                .flatMap(p -> Stream.concat(Stream.of("###@@@ " + p), readAllLinesFromResource(p)))
                .filter(l -> !l.equals(HASH_BANG))
                .collect(Collectors.toList());
        lines.add(0, HASH_BANG);

        lines.forEach(System.out::println);
    }

    private static void showVersion() {
        String version = readAllLinesFromResource(PROJECT)
                .filter(l -> l.startsWith("version="))
                .map(l -> l.replaceAll("version=", ""))
                .map(l -> l.replaceAll("\"", ""))
                .findFirst().orElseThrow(() -> new Error("version not found in " + PROJECT));
        System.out.println(version);
    }

    private static void checkMeme() {
        checkMeme(MEME);
    }

    private static void checkMeme(Path file) {
        if (Files.isReadable(file)) {
            try {
                List<String> actMeme = Files.readAllLines(file);
                List<String> expMeme = getMemeLines();
                if (!expMeme.equals(actMeme)) {
                    poormansDiff(file, actMeme, expMeme).forEach(System.err::println);
                }
            } catch (IOException e) {
                System.err.println("::warning::could not read meme at " + file.toAbsolutePath());
            }
        }
    }

    private static List<String> getMemeLines() {
        return readAllLinesFromResource(MEME).collect(Collectors.toList());
    }

    private static Path getMyPath() {
        return Paths.get(Extractor.class.getName().replace('.', '/') + ".class");
    }

    private static Optional<Path> whereInClassPath(Path toFind) {
        return classpathStream().filter(p -> contains(p, toFind)).findAny();
    }

    private static Stream<Path> classpathStream() {
        return Stream.of(CLASS_PATH.split(CP_SEP)).map(Paths::get);
    }

    private static boolean contains(Path p, Path toFind) {
        return walk(p).anyMatch(pp -> pp.endsWith(toFind));
    }

    private static Stream<Path> walk(Path p) {
        Stream<Path> pathStream = Files.isDirectory(p) ? dirWalk(p) : jarWalk(p);
        return pathStream == null ? Stream.empty() : pathStream;
    }

    private static Stream<Path> dirWalk(Path p) {
        try {
            return Files.walk(p)
                    .filter(sub -> !Files.isDirectory(sub))
                    .map(p::relativize)
                    //.peek(sub -> System.err.println(" ddd " + sub))
                    ;
        } catch (IOException e) {
            throw new Error("can not walk dir", e);
        }
    }

    private static Stream<Path> jarWalk(Path p) {
        try {
            return new ZipFile(p.toFile()).stream()
                    //.peek(ze -> System.err.println(" zzz " + ze))
                    .map(ze -> Paths.get(ze.getName()));
        } catch (IOException e) {
            throw new Error("can not walk jar", e);
        }
    }

    private static Stream<String> readAllLinesFromResource(Path p) {
        InputStream inp = Thread.currentThread().getContextClassLoader().getResourceAsStream(p.toString());
        if (inp == null) {
            throw new Error("can not find resource: " + p);
        }
        return new BufferedReader(new InputStreamReader(inp)).lines();
    }

    private static Stream<String> poormansDiff(Path meme, List<String> act, List<String> exp) {
        List<Integer> uniqueHashes = Stream.concat(
                act.stream().distinct(),
                exp.stream().distinct()
        )
                .map(String::hashCode)
                .collect(Collectors.groupingBy(Function.identity(), Collectors.counting()))
                .entrySet()
                .stream()
                .filter(p -> 1 == p.getValue())
                .map(Entry::getKey)
                .collect(Collectors.toList());

        List<String> l = new ArrayList<>();
        l.add("------------------------------------------------------------------------------------------------------------------------");
        l.add("WARNING: your meme at " + meme + " is out of date:");
        l.add("-------- only in your version: -----------------------------------------------------------------------------------------");
        l.addAll(addUniqueLines(uniqueHashes, act));
        l.add("-------- only in expected version: -------------------------------------------------------------------------------------");
        l.addAll(addUniqueLines(uniqueHashes, exp));
        l.add("------------------------------------------------------------------------------------------------------------------------");

        return l.stream();
    }

    private static List<String> addUniqueLines(List<Integer> uniqueHashes, List<String> lines) {
        return IntStream.range(0, lines.size())
                .boxed()
                .collect(Collectors.toMap(n -> n, lines::get))
                .entrySet()
                .stream()
                .sorted(Comparator.comparingInt(Entry::getKey))
                .filter(e -> uniqueHashes.contains(e.getValue().hashCode()))
                .map(e -> String.format("%4d %s", e.getKey(), e.getValue()))
                .collect(Collectors.toList());
    }
}
