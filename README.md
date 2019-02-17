# TodoistToBear ![badge-languages]

Small Swift script that imports tasks from [Todoist](https://todoist.com/overview) into [Bear](https://bear.app) as notes with checklists.

# Usage

First, export your tasks from Todoist with [Export for Todoist](https://darekkay.com/todoist-export/) in **JSON format**.

Then run the script passing the path to the JSON file:

```
./todoistbear.swift /Users/user/Downloads/todoist-2.json 
```

You will then be prompted for each Project found:

1. Display project? 

You can say "no" to skip this project. It's useful if you already run the script and the project is already in Bear, or you just don't want to import this one.

2. Add to Bear?

Answer "yes" to conitnue the process of adding this project to Bear.

3. Use TODO list style?

Answering "yes" will format the task list as a checklist, so it will use `- [ ]` markdown format. 

Answering "no" will format the task list as a simple unordered list, so it will use `- `.

After this you will see how Bear is opened and a new Note is added with a list of yout tasks from Todoist. 🎉 

# Format details

The script has the option to make the notes with unordered lists or checklist. 

It will create a single note per Project. Sub-projects are added in the same note separated by headers.

Subtasks are indented below its parent task to reflect the hierarchy.

# Requirements

- [Export for Todoist](https://darekkay.com/todoist-export/) to generate the JSON.
- Swift 4.2
- [swift-sh](https://github.com/mxcl/swift-sh) or [Marathon](https://github.com/JohnSundell/Marathon) to run the script as it has a dependency.
- Bear needs to be installed on the machine.

# Author

Alejandro Martinez | [http://alejandromp.com](http://alejandromp.com/) | [@alexito4](https://twitter.com/alexito4)

[badge-languages]: https://img.shields.io/badge/swift-4.2-orange.svg