import * as React from 'react';
import axios from "axios";

import MonkeyState from './MonkeyState'
import FormControl from '@mui/material/FormControl';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import MenuItem from '@mui/material/MenuItem';
import Grid from '@mui/material/Grid2';
import Button from '@mui/material/Button';
import Paper from '@mui/material/Paper';
import Box from '@mui/material/Box';
import FormGroup from '@mui/material/FormGroup';
import FormControlLabel from '@mui/material/FormControlLabel';
import Checkbox from '@mui/material/Checkbox';

class TestFlags extends React.Component {
    constructor(props) {
        super(props);
        this.state = {
            hashnewalg_on: false,
            mysql_on: false,
            gozero_on: false
        };

        this.monkeyState = new MonkeyState(this, 'flags');

        this.handleInputChange = this.handleInputChange.bind(this);
        this.handleSubmit = this.handleSubmit.bind(this);
    }

    handleInputChange(event) {
        const target = event.target;
        const value = target.type === 'checkbox' ? target.checked : target.value;
        const name = target.name;

        this.setState({
            [name]: value
        });
    }

    async handleSubmit(event) {
        event.preventDefault();

        try {
            if (this.state.hashnewalg_on === false) {
                await axios.delete(`/monkey/flags/HASHNEWALG`);
            } else {
                await axios.post(`/monkey/flags/HASHNEWALG`);
            }
            if (this.state.mysql_on === false) {
                await axios.delete(`/monkey/flags/MYSQL`);
            } else {
                await axios.post(`/monkey/flags/MYSQL`);
            }
            if (this.state.gozero_on === false) {
                await axios.delete(`/monkey/flags/GOZERO`);
            } else {
                await axios.post(`/monkey/flags/GOZERO`);
            }

            this.monkeyState.fetchData();
        } catch (err) {
            console.log(err.message)
        }
    }

    render() {
        return (
            <form name="flags" onSubmit={this.handleSubmit}>
                <Grid container spacing={2}>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='hashnewalg_on'
                            checked={this.state.hashnewalg_on}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="Test New Hashing Algorithm" />
                    </FormGroup>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='mysql_on'
                            checked={this.state.mysql_on}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="Test MySQL Database" />
                    </FormGroup>
                    <FormGroup>
                        <FormControlLabel control={<Checkbox
                            name='gozero_on'
                            checked={this.state.gozero_on}
                            onChange={this.handleInputChange}
                            inputProps={{ 'aria-label': 'controlled' }}
                        />} label="Test Go Zero Instrumentation (ebpf)" />
                    </FormGroup>

                    <Box width="100%"><Button variant="contained" data-transaction-name="TestFlags" type="submit">Submit</Button></Box>
                    {this.monkeyState.render()}
                </Grid>
            </form>
        );
    }
}

export default TestFlags;