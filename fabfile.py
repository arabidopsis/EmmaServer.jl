from __future__ import annotations

# install fabric with click support
# uv tool install fabric --with=click
# now you can run commands like:
# fab update


from click import echo  # type: ignore
from click import secho  # type: ignore
from click import style as color  # type: ignore
from fabric import task  # type: ignore

MACHINES = {
    "ianc@viridis2": "/var/data/www/websites/emma/EmmaServer.jl",
}
SERVICE = "emma-annotator.service"
URL = "http://127.0.0.1:9998"
HOSTS = list(MACHINES)


def git_uptodate(res):
    # Already up-to-date or Already up to date
    # is there a better way
    return res.stdout.lower().startswith("already up")


def get_srdir(c):
    return MACHINES[f"{c.user}@{c.original_host}"]


@task(hosts=HOSTS)
def update(c):
    """Update EmmaServer.jl code from github and restart (if any changes)."""
    with c.cd(get_srdir(c)):
        pwd = c.run("pwd", hide=True)
        echo("pulling from: " + color(pwd.stdout.strip(), fg="yellow"))
        result = c.run("uname -a", hide=True)
        # ,result.failed,result.return_code,result.succeeded
        echo(color(result.stdout.strip(), fg="green"))
        res = c.run("git pull", warn=True)

        if not res.failed and not git_uptodate(res):
            # secho("touching app/app.wsgi", fg="blue", bold=True)
            # c.run("touch app/app.wsgi")
            secho("instantiate", fg="green", bold=True)
            result = c.run("make instantiate", warn=True)
            if result.failed:
                secho("make instantiate failed!", fg="red", bold=True)
                return
            secho("restarting EmmaServer.jl", fg="blue", bold=True)
            c.run(f"sudo systemctl restart {SERVICE}", pty=True)


@task(hosts=HOSTS)
def status(c):
    """Show status of emma-annotator service."""
    c.run(f"systemctl status {SERVICE}", pty=True)


@task(hosts=HOSTS)
def restart(c):
    """restart emma-annotator service."""
    c.run(f"sudo systemctl restart {SERVICE}", pty=True)


@task(hosts=HOSTS)
def server_config(c):
    """get the EmmaServer.jl server config."""
    import json
    import pprint

    ret = c.run(f"curl --silent {URL}/config", hide=True)
    j = json.loads(ret.stdout)
    pprint.pprint(j["data"])


@task(hosts=HOSTS)
def show_service(c):
    """show the EmmaServer.jl service file."""
    c.run(f"cat /etc/systemd/system/{SERVICE}")


@task(hosts=HOSTS)
def ping(c):
    """ping the EmmaServer.jl server."""
    import json

    ret = c.run(f"curl --silent {URL}/ping", hide=True)
    j = json.loads(ret.stdout)
    print(j["data"])
