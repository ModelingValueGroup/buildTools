#!/usr/bin/env bash

for f in src/*.sh; do
  . "$f"
done

tmp=./tmp
rm -rf $tmp
mkdir $tmp
cd $tmp

selectBase sonatype
mkdir -p a b
nexusArtifactRedirect "junit:junit:LATEST:jar" $REPOS_RELEASES a
nexusArtifactContent  "junit:junit:LATEST:jar" $REPOS_RELEASES b
nexusArtifactResolve  "junit:junit:LATEST:jar" $REPOS_RELEASES
file */*
###############################################


#curl "$NEXUS_BASE/$REST_PATH/repositories/$r/content/${g//.//}/$a/maven-metadata.xml" -o -
#https://repository.sonatype.org/service/local/components/schedule_types
#https://maven.pkg.github.com/service/local
#dummy-org-gsd-days    spring-boot-example    0.0.8
#https://maven.pkg.github.com/dummy-org-gsd-days/spring-boot-example/service/local/artifact/maven/redirect?r=snapshots&g=org.sonatype.nexus&a=nexus-utils&v=LATEST&e=jar
#https://maven.pkg.github.com/dummy-org-gsd-days/spring-boot-example/service/local/artifact/maven/redirect?r=snapshots&g=dummy-org-gsd-days&a=spring-boot-example&v=LATEST
