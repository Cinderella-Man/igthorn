window.renderChart = (labels, symbol, data) => {
    if(["complete", "loaded", "interactive"].indexOf(document.readyState) >= 0){
        doRender(labels, symbol, data)
    } else {
        document.addEventListener("DOMContentLoaded", () => doRender(labels, symbol, data))
    }
}

let doRender = (labels, symbol, data) => {

    if (window.chart !== undefined) {
        window.chart.destroy();
    }

    var ctx = document.getElementById('lineChart');

    var chartData = {
        labels: labels,
        datasets: [{
            label: symbol,
            backgroundColor: 'rgb(255, 99, 132)',
            borderColor: 'rgb(255, 99, 132)',
            data: data,
            fill: false
        }]
    }

    window.chart = new Chart(ctx, {
        // The type of chart we want to create
        type: 'line',
        // The data for our dataset
        data: chartData,
        // Configuration options go here
        options: {
            responsive: true,
            tooltips: {
                mode: 'index',
                intersect: false,
            },
            scales: {
                xAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Time'
                    }
                }],
                yAxes: [{
                    display: true,
                    scaleLabel: {
                        display: true,
                        labelString: 'Price'
                    }
                }]
            }
        }
    });
}