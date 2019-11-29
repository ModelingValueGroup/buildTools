const spawn = require('child_process').spawn;
const path  = require("path");

const exec = (cmd, args=[]) => new Promise((resolve, reject) => {
    const app = spawn(cmd, args, { stdio: 'inherit' });
    app.on('close', resolve);
    app.on('error', reject);
    app.on('exit', code => {if (code!=0) process.exit(code);});
});

const main = async () => {
    await exec('bash', [path.join(__dirname, './entrypoint.sh')]);
};

main().catch(err => {
    console.error(err);
    console.error(err.stack);
    process.exit(-1);
})
