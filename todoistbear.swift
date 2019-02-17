#!/usr/bin/swift sh

import Foundation
import Cocoa
import Swiftline // @Swiftline == master //marathon:https://github.com/Swiftline/Swiftline.git

guard CommandLine.arguments.count == 2 else {
    print("Path to todoist.json must be provided.".f.Red)
    print("Export the json using https://darekkay.com/todoist-export/".f.Red)
    exit(EXIT_SUCCESS) // marathon doesn't show errors?
}
let path = CommandLine.arguments[1]
let data = try! Data(contentsOf: URL(fileURLWithPath: path))

struct Body: Decodable {
    let projects: [Project]
    let items: [Task]
    
    struct Project: Decodable {
        let id: Int
        let parent_id: Int?
        let name: String
    }
    struct Task: Decodable {
        let id: Int
        let content: String
        let project_id: Int
        let checked: Int
        let parent_id: Int?
    }
}

class Project: CustomDebugStringConvertible, Hashable {
    let id: Int
    var parent: Project?
    var subprojects: Set<Project>
    var name: String
    var tasks: [Task]
    
    init(
        id: Int) {
        self.id = id
        self.parent = nil
        self.subprojects = []
        self.name = ""
        self.tasks = []
    }
    
    var debugDescription: String {
        var subString = ""
        if subprojects.isEmpty == false {
            subString += "\n"
            for sp in subprojects.sorted(by: { $0.id < $1.id }) {
                subString += " " + sp.debugDescription
            }
        }
        return "\(id): \(name) \(subString) \n\(tasks)"
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
class Task {
    let id: Int
    var content: String
    var project: Project!
    var done: Bool
    var subtasks: [Task]
    
    init(id: Int) {
        self.id = id
        self.content = ""
        self.project = nil
        self.done = false
        self.subtasks = []
    }
    
    func setChecked(_ checked: Int) {
        done = checked > 0 ? true : false
    }
}

var allProjects = [Project]()
var allTasks = [Task]()

extension Array where Element == Project {
    mutating func findOrCreateProject(id: Int) -> Project {
        if let found = first(where: { $0.id == id }) {
            return found
        } else {
            let p = Project(id: id)
            append(p)
            return p
        }
    }
}

extension Array where Element == Task {
    mutating func findOrCreateTask(id: Int) -> Task {
        if let found = first(where: { $0.id == id }) {
            return found
        } else {
            let task = Task(id: id)
            append(task)
            return task
        }
    }
}

let body = try! JSONDecoder().decode(Body.self, from: data)

for p in body.projects {
    let project = allProjects.findOrCreateProject(id: p.id)
    project.name = p.name
    
    if let parentId = p.parent_id {
        let parent = allProjects.findOrCreateProject(id: parentId)
        project.parent = parent
        parent.subprojects.insert(project)
    }
}
for i in body.items {
    let task = allTasks.findOrCreateTask(id: i.id)
    task.content = i.content
    task.setChecked(i.checked)
    
    if let parentId = i.parent_id {
        let parentTask = allTasks.findOrCreateTask(id: parentId)
        parentTask.subtasks.append(task)
    } else {
        // Only add to project if is not a subtask.
        // Tree: Project -> Subproject -> Task -> Subtask
        let project = allProjects.first(where: { $0.id == i.project_id })!
        task.project = project
        project.tasks.append(task)
    }
}

extension Project {
    func generateOutput(todoStyle: Bool, hs: Int = 1) -> String {
        var output = ""
        
        if hs > 1 { // Don't add the H1 for the first header, the TITLE of the note will have it.
            let headings = String(repeating: "#", count: hs)
            output += "\n\(headings) \(name)\n\n"
        }
        
        func appendTaskOutput(_ tasks: [Task], level: Int) {
            for task in tasks {
                output += taskOutput(task, todoStyle: todoStyle, level: level)
                appendTaskOutput(task.subtasks, level: level + 1)
            }
        }
        
        appendTaskOutput(tasks, level: 0)
        
        if subprojects.isEmpty == false {
            for sp in subprojects.sorted(by: { $0.id < $1.id }) {
                output += sp.generateOutput(todoStyle: todoStyle, hs: hs + 1)
            }
        }
        
        return output
    }
    
    func taskOutput(_ task: Task, todoStyle: Bool, level: Int) -> String {
        let taskString: String
        if todoStyle {
            if task.done {
                taskString = " [x]"
            } else {
                taskString = " [ ]"
            }
        } else {
            if task.done {
                taskString = " DONE"
            } else {
                taskString = ""
            }
            
        }
        let indent = String(repeating: "  ", count: level)
        return "\(indent)-\(taskString) \(task.content)\n"
    }
}

extension URLQueryItem {
    init?(name: String, requiredValue: String?) {
        guard let value = requiredValue else { return nil }
        self.init(name: name, value: value)
    }
    init?(name: String, nonEmpty array: [String]) {
        guard array.isEmpty == false else { return nil }
        self.init(name: name, value: array.joined(separator: ","))
    }
}

enum Bear {
    static func send(_ action: Action) {
        var components = URLComponents(string: "bear://x-callback-url/\(action.name)")
        components?.queryItems = action.parameters
        
        guard let url = components?.url else {
            return
        }
        
        print(url)
        
        NSWorkspace.shared.open(url)
    }
    
    enum Action {
        /*
         /create
         Create a new note and return its unique identifier. Empty notes are not allowed.
         
         parameters
         
         title optional note title.
         text optional note body.
         tags optional a comma separated list of tags.
         file optional base64 representation of a file.
         filename optional file name with extension. Both file and filename are required to successfully add a file.
         open_note optional if no do not display the new note in Bear's main or external window.
         new_window optional if yes open the note in an external window (MacOS only).
         show_window optional if no the call don't force the opening of bear main window (MacOS only).
         pin optional if yes pin the note to the top of the list.
         edit optional if yes place the cursor inside the note editor.
         timestamp optional if yes prepend the current date and time to the text
         x-success
         
         identifier note unique identifier.
         title note title.
         example
         
         bear://x-callback-url/create?title=My%20Note%20Title&text=First%20line&tags=home,home%2Fgroceries
         
         notes
         
         The base64 file parameter have to be encoded when passed as an url parameter.
        */
        case create(title: String?, text: String?, tags: [String])
        
        var name: String {
            switch self {
            case .create:
                return "create"
            }
        }
        
        var parameters: [URLQueryItem] {
            switch self {
            case .create(let title, let text, let tags):
                return [
                    URLQueryItem(name: "title", requiredValue: title),
                    URLQueryItem(name: "text", requiredValue: text),
                    URLQueryItem(name: "tags", nonEmpty: tags),
                ].compactMap({$0})
            }
        }
    }
}

let projects = allProjects
    .filter({ $0.parent == nil })

print("Found \(projects.count)".f.Yellow)

for p in projects {
    guard agree("Display \(p.name)? {\(p.id)}".f.Yellow) else { continue }
    print(
        p.generateOutput(todoStyle: false)
    )
    guard agree("Add to Bear?".f.Yellow) else { continue }
    
    let todoStyle = agree("Use TODO list style?")
    
    let title = p.name
    let text = p.generateOutput(todoStyle: todoStyle)
    
    Bear.send(.create(title: title, text: text, tags: []))
}
