using AtomiCloud.DotnetBase.Lib.Note;
using FluentAssertions;

namespace AtomiCloud.DotnetBase.UnitTest.Note;

public class DeadCodeProbe_Describe
{
    [Fact]
    public void It_should_return_the_probe_label()
    {
        DeadCodeProbe.Describe().Should().Be("dead-code proof test and program");
    }
}
