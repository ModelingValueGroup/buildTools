//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// (C) Copyright 2018-2019 Modeling Value Group B.V. (http://modelingvalue.org)                                        ~
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

package correctors;

import static java.lang.Integer.min;

import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

public class HeaderCorrector extends CorrectorBase {
    private static final URL                 headerUrl  = getUrl("https://raw.githubusercontent.com/ModelingValueGroup/generic-info/master/header");
    private static final Map<String, String> EXT_TO_PRE = new HashMap<>();

    static {
        EXT_TO_PRE.put("java", "//");
        EXT_TO_PRE.put("sh", "##");
        EXT_TO_PRE.put("yaml", "##");
        EXT_TO_PRE.put("yml", "##");
        EXT_TO_PRE.put("js", "//");
    }

    @SuppressWarnings("SameParameterValue")
    private static URL getUrl(String url) {
        try {
            return new URL(url);
        } catch (MalformedURLException e) {
            throw new Error("unlikely error", e);
        }
    }

    public static void main(String[] args) throws IOException {
        new HeaderCorrector(args).generate();
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    private final Path                      optHeaderFile;
    private final List<String>              headerLines;
    private final Map<String, List<String>> ext2header = new HashMap<>();

    public HeaderCorrector(String[] args) {
        super("header");

        if (args.length == 0) {
            try (InputStream in = headerUrl.openStream()) {
                optHeaderFile = null;
                headerLines = replaceVars(Arrays.asList(new String(in.readAllBytes(), StandardCharsets.UTF_8).split("\n")));
                System.err.println("header taken from " + headerUrl);
            } catch (IOException e) {
                throw new Error("can not download header from github " + headerUrl, e);
            }
        } else if (args.length == 1) {
            optHeaderFile = Paths.get(args[0]);
            if (!Files.isRegularFile(optHeaderFile)) {
                throw new Error("no such file: " + optHeaderFile);
            }
            headerLines = replaceVars(readAllLines(optHeaderFile));
            System.err.println("header taken from " + optHeaderFile.toAbsolutePath());
        } else {
            throw new Error("usage: HeaderCorrector [headerFile]");
        }
    }

    private List<String> replaceVars(List<String> lines) {
        return lines.stream().map(this::replaceVars).collect(Collectors.toList());
    }

    private String replaceVars(String line) {
        return line.replaceAll("yyyy", ""+LocalDateTime.now().getYear());
    }

    private void generate() throws IOException {
        allFiles().forEach(this::replaceHeader);
    }

    private void replaceHeader(Path f) {
        if (needsHeader(f)) {
            String       ext        = getExtension(f.getFileName().toString()).orElseThrow();
            List<String> header     = ext2header.computeIfAbsent(ext, e -> border(EXT_TO_PRE.get(e)));
            List<String> lines      = readAllLines(f);
            boolean      isHashBang = !lines.isEmpty() && lines.get(0).startsWith("#!");
            int          baseIndex  = isHashBang ? 1 : 0;
            while (baseIndex < lines.size() && isHeaderLine(lines.get(baseIndex), ext)) {
                lines.remove(baseIndex);
            }
            isHashBang = !lines.isEmpty() && lines.get(0).startsWith("#!");
            baseIndex = isHashBang ? 1 : 0;
            lines.addAll(baseIndex, header);
            overwrite(f, lines);
        }
    }

    private boolean needsHeader(Path f) {
        Optional<String> ext = getExtension(f.getFileName().toString());
        return getFileSize(f) != 0 && !f.equals(optHeaderFile) && ext.isPresent() && EXT_TO_PRE.containsKey(ext.get());
    }

    @SuppressWarnings("OptionalGetWithoutIsPresent")
    private List<String> border(String pre) {
        List<String> cleaned  = cleanup(pre, headerLines);
        int          len      = cleaned.stream().mapToInt(String::length).max().getAsInt();
        String       border   = pre + "~" + String.format("%" + len + "s", "").replace(' ', '~') + "~~";
        List<String> bordered = cleaned.stream().map(l -> String.format(pre + " %-" + len + "s ~", l)).collect(Collectors.toList());
        bordered.add(0, border);
        bordered.add(border);
        bordered.add("");
        return bordered;
    }

    private List<String> cleanup(String pre, List<String> inFile) {
        List<String> h = inFile
                .stream()
                .map(String::stripTrailing)
                .filter(l -> !l.matches("^" + pre + "~~*$") && !l.matches("^//" + "~~*$"))
                .map(l -> l.replaceAll("^" + pre, ""))
                .map(l -> l.replaceAll("^//", ""))
                .map(l -> l.replaceAll("~$", ""))
                .map(String::stripTrailing)
                .collect(Collectors.toList());
        int indent = calcIndent(h);
        if (0 < indent) {
            h = h.stream().map(l -> l.substring(min(l.length(), indent))).collect(Collectors.toList());
        }
        while (!h.isEmpty() && h.get(0).trim().isEmpty()) {
            h.remove(0);
        }
        while (!h.isEmpty() && h.get(h.size() - 1).trim().isEmpty()) {
            h.remove(h.size() - 1);
        }
        if (h.isEmpty()) {
            h.add("no header available");
        }
        return h;
    }

    private boolean isHeaderLine(String line, String ext) {
        return (line.startsWith(EXT_TO_PRE.get(ext)) && line.endsWith("~")) || line.trim().isEmpty();
    }

    private int calcIndent(List<String> h) {
        int indent = Integer.MAX_VALUE;
        for (String l : h) {
            if (l.trim().length() != 0) {
                indent = min(indent, l.replaceAll("[^ ].*", "").length());
            }
        }
        return indent;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    private static List<String> readAllLines(Path f) {
        try {
            return Files.readAllLines(f);
        } catch (IOException e) {
            throw new Error("could not read lines: " + f, e);
        }
    }

    private static long getFileSize(Path f) {
        try {
            return Files.size(f);
        } catch (IOException e) {
            throw new Error("file size failed", e);
        }
    }
}
