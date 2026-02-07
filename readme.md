This is the initial commit.

I've left in the .vscode folder and files because who cares it could help someone.

## Merlin
This is a tinkler project to bring in OOP ideals into LUA. I'm sure that has been done a thousand times, but I'm here to add 1 to that counter.

#### Basic Use
This is based on the Project Zomboid LUA objects in that you are only
expected to write `local SomeChildClass = Merlin:derive("SomeChildClass")` and then define the class however you like and then `local instanceOfSomeChildClass = SomeChildClass:new()`. The rest should be done for you. If you have initialization logic it should be placed into `SomeChildClass:__init()`.

I don't have much documentation yet as I'm writing and using at the same time so I'd like to see it in the wild to get better ideas of how it could or should be used.

#### Worth Note
The name `Merlin` is just a placeholder name because I knew I was gonna be playing around a lot with LUA's magic methods.

#### Also
I promise I'm good at documentation. I just don't think it's time yet but I'm happy to show what I intend, though, I'd
rather people just use it wildly so I can see what needs to be addressed, fixed, ignored.