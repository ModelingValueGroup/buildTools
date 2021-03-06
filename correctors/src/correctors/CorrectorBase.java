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
import java.nio.file.Paths;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Stream;

@SuppressWarnings({"WeakerAccess"})
public abstract class CorrectorBase {
    static final Set<Path> FORBIDDEN_DIRS = new HashSet<>(Arrays.asList(
            Paths.get("./MPS"),
            Paths.get("./.git"),
            Paths.get("./.idea"),
            Paths.get("./out"),
            Paths.get("./lib"),
            Paths.get("./.github/workflows/") // github refuses bot pushes of workflows
    ));

    private final String name;

    public CorrectorBase(String name) {
        this.name = name;
    }

    Stream<Path> allFiles() throws IOException {
        return Files.walk(Paths.get("."))
                .filter(p -> FORBIDDEN_DIRS.stream().noneMatch(p::startsWith))
                .filter(Files::isRegularFile);
    }

    void overwrite(Path file, List<String> lines) {
        overwrite(file, lines, false);
    }

    void overwrite(Path file, List<String> lines, boolean forced) {
        removeTrailingEmptyLines(lines);
        try {
            if (forced || !Files.isRegularFile(file)) {
                System.err.println("+ " + name + " generated  : " + file);
                Files.write(file, lines);
            } else {
                List<String> old = Files.readAllLines(file);
                removeTrailingEmptyLines(old);
                if (!lines.equals(old)) {
                    System.err.println("+ " + name + " regenerated: " + file);
                    Files.write(file, lines);
                } else {
                    System.err.println("+ " + name + " ok         : " + file);
                }
            }
        } catch (IOException e) {
            throw new Error("could not overwrite file for " + name + " : " + file, e);
        }
    }

    private void removeTrailingEmptyLines(List<String> lines) {
        Collections.reverse(lines);
        while (!lines.isEmpty() && lines.get(0).trim().length()==0) {
            lines.remove(0);
        }
        Collections.reverse(lines);
    }

    static Optional<String> getExtension(String filename) {
        return Optional.ofNullable(filename)
                .filter(f -> f.contains("."))
                .map(f -> f.substring(f.lastIndexOf(".") + 1));
    }
}
