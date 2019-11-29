package tools;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;
import java.util.zip.*;

public class Extractor {
    private static final String CP_SEP     = System.getProperty("path.separator");
    private static final String CLASS_PATH = System.getProperty("java.class.path", ".");
    private static final String HASH_BANG  = "#!/usr/bin/env bash";
    private static final String SH_EXT     = ".sh";
    private static final String UNFINISHED = "unfinished";

    public static void main(final String[] args) {
        Path ourClassPathElement = whereInClassPath(getMyPath()).orElseThrow();

        List<String> lines = walk(ourClassPathElement)
                .filter(p -> p.getFileName().toString().endsWith(SH_EXT))
                .filter(p -> !p.startsWith(UNFINISHED))
                .sorted()
                .flatMap(p -> Stream.concat(Stream.of("###@@@ " + p), readAllLines(p)))
                .filter(l -> !l.equals(HASH_BANG))
                .collect(Collectors.toList());
        lines.add(0, HASH_BANG);

        lines.forEach(System.out::println);
    }

    private static Path getMyPath() {
        return Paths.get(Extractor.class.getName().replace('.', '/') + ".class");
    }

    private static Optional<Path> whereInClassPath(Path toFind) {
        return classpathStream().filter(p -> contains(p, toFind)).findAny();
    }

    private static Stream<Path> classpathStream() {
        return Stream.of(CLASS_PATH.split(CP_SEP)).map(s -> Paths.get(s));
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

    private static Stream<String> readAllLines(Path p) {
        InputStream inp = Thread.currentThread().getContextClassLoader().getResourceAsStream(p.toString());
        if (inp == null) {
            throw new Error("can not find resource: " + p);
        }
        return new BufferedReader(new InputStreamReader(inp)).lines();
    }
}
