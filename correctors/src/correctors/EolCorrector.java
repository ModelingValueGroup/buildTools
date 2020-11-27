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

package correctors;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

@SuppressWarnings("ArraysAsListWithZeroOrOneArgument")
public class EolCorrector extends CorrectorBase {
    private static final Set<String> TEXT_FILES         = new HashSet<>(Arrays.asList(
            ".gitignore",
            ".gitattributes",
            "LICENSE",
            "header"
    ));
    private static final Set<String> NO_TEXT_FILES      = new HashSet<>(Arrays.asList(
            ".DS_Store"
    ));
    private static final Set<String> TEXT_EXTENSIONS    = new HashSet<>(Arrays.asList(
            "MF",
            "java",
            "java",
            "js",
            "md",
            "pom",
            "properties",
            "sh",
            "txt",
            "xml",
            "yaml",
            "yml",
            "adoc",
            "project",
            "prefs",
            "classpath",
            "jardesc",
            "mps",
            "mpl",
            "msd"
            ));
    private static final Set<String> NO_TEXT_EXTENSIONS = new HashSet<>(Arrays.asList(
            "class",
            "iml",
            "jar",
            "jar",
            "jpeg",
            "jpg",
            "png"
    ));

    public static void main(String[] args) throws IOException {
        if (args.length != 0) {
            System.err.println("no args expected");
            System.exit(31);
        }
        new EolCorrector().generate();
    }

    public EolCorrector() {
        super("eols");
    }

    private void generate() throws IOException {
        allFiles()
                .filter(this::isTextType)
                .forEach(this::correctCRLF);
    }

    private void correctCRLF(Path f) {
        try {
            List<String> lines   = Files.readAllLines(f);
            String       all     = Files.readString(f);
            int          numcr   = all.replaceAll("[^\r]", "").length();
            int          numlf   = all.replaceAll("[^\n]", "").length();
            boolean      lfAtEnd = all.charAt(all.length() - 1) == '\n';
            if (numcr > 0 || lines.size() != (lfAtEnd ? numlf : numlf - 1)) {
                System.err.printf("rewriting file: %4d lines (%4d cr and %4d lf, %s at end) - %s\n", lines.size(), numcr, numlf, lfAtEnd ? "lf" : "no lf", f);
                overwrite(f, lines, true);
                //} else{
                //System.err.printf("NOT rewriting file: %4d lines (%4d cr and %4d lf, %s at end) - %s\n", lines.size(), numcr, numlf, lfAtEnd ? "lf" : "no lf", f);
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    private boolean isTextType(Path f) {
        String           filename = f.getFileName().toString();
        Optional<String> ext      = getExtension(filename);
        if (size(f) == 0L) {
            return false;
        }
        if (TEXT_FILES.contains(filename)) {
            return true;
        }
        if (NO_TEXT_FILES.contains(filename)) {
            return false;
        }
        if (ext.isEmpty()) {
            return false;
        }
        if (TEXT_EXTENSIONS.contains(ext.get())) {
            return true;
        }
        if (NO_TEXT_EXTENSIONS.contains(ext.get())) {
            return false;
        }
        System.err.println("WARNING: unknown file type (not correcting cr/lf): " + f);
        return false;
    }

    private long size(Path f) {
        try {
            return Files.size(f);
        } catch (IOException e) {
            throw new Error("file size failed", e);
        }
    }
}
