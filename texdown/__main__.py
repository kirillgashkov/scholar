import click


@click.command()
@click.option("--output", "-o", type=click.File("w"))
@click.argument("input", type=click.File("r"))
def texdown(output: click.File("w"), input: click.File("r")) -> None:
    pass


if __name__ == "__main__":
    texdown()
