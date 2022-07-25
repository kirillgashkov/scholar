import click


@click.command()
@click.option("--output", "-o", type=str, help="A PDF file to output to")
@click.argument("input", type=str, help="A Markdown file to convert")
def texdown(output: str, input: str) -> None:
    pass


if __name__ == "__main__":
    texdown()
