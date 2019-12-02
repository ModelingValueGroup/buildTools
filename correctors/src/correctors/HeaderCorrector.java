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

import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.stream.*;

import static java.lang.Integer.*;

public class HeaderCorrector extends CorrectorBase {
    private static final Map<String, String> EXT_TO_PRE = new HashMap<>();

    static {
        EXT_TO_PRE.put("java", "//");
        EXT_TO_PRE.put("sh", "##");
    }

    private Path                      headerFile = Paths.get("build", "header").toAbsolutePath();
    private Map<String, List<String>> ext2header = new HashMap<>();

    public static void main(String[] args) throws IOException {
        new HeaderCorrector().prepare(Arrays.asList(args)).generate();
    }

    private HeaderCorrector prepare(List<String> args) {
        if (args.size() != 1) {
            System.err.println("arg error: one arg expected: <header-template-file>");
            System.exit(53);
        }
        headerFile = Paths.get(args.get(0));

        if (!Files.isRegularFile(headerFile)) {
            throw new Error("no such file: " + headerFile);
        }
        return this;
    }

    private void generate() throws IOException {
        allFiles()
                .filter(this::needsHeader)
                .forEach(this::replaceHeader);
    }

    private boolean needsHeader(Path f) {
        Optional<String> ext = getExtension(f.getFileName().toString());
        try {
            if (Files.size(f) == 0) {
                return false;
            }
            if (f.equals(headerFile)) {
                return true;
            }
            if (ext.isEmpty()) {
                return false;
            }
            return EXT_TO_PRE.containsKey(ext.get());
        } catch (IOException e) {
            throw new Error("file size failed", e);
        }
    }

    private void replaceHeader(Path f) {
        String       ext    = getExtension(f.getFileName().toString()).orElseThrow();
        List<String> header = ext2header.computeIfAbsent(ext, e -> readHeader(EXT_TO_PRE.get(e)));

        List<String> lines      = f.equals(headerFile) ? new ArrayList<>() : readAllLines(f);
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

    private boolean isHeaderLine(String line, String ext) {
        return (line.startsWith(EXT_TO_PRE.get(ext)) && line.endsWith("~")) || line.trim().isEmpty();
    }

    private List<String> readHeader(String pre) {
        Path f = this.headerFile;
        return border(pre, cleanup(pre, readAllLines(f)));
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

    private List<String> border(String pre, List<String> cleaned) {
        //noinspection OptionalGetWithoutIsPresent
        int          len      = cleaned.stream().mapToInt(String::length).max().getAsInt();
        String       border   = pre + "~" + String.format("%" + len + "s", "").replace(' ', '~') + "~~";
        List<String> bordered = cleaned.stream().map(l -> String.format(pre + " %-" + len + "s ~", l)).collect(Collectors.toList());
        bordered.add(0, border);
        bordered.add(border);
        bordered.add("");
        return bordered;
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

    private static List<String> readAllLines(Path f) {
        try {
            return Files.readAllLines(f);
        } catch (IOException e) {
            throw new Error("could not read lines: " + f, e);
        }
    }
}
